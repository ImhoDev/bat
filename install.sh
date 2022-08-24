#!/bin/bash

HOST=${1:-'dominio'}
#parametros opcionales
PROYECT=${2:-'https://gitlab.com/b.mendoza/facturadorpro3.git'}
REMOTE='git@gitlab.com:'$(echo $PROYECT | sed -e s#^https://gitlab.com/##)
SERVICE_NUMBER=${3:-'1'}
PATH_INSTALL=$(echo $HOME)
DIR=$(echo $PROYECT | rev | cut -d'/' -f1 | rev | cut -d '.' -f1)$SERVICE_NUMBER
MYSQL_PORT_HOST=${4:-'3306'}
MYSQL_USER=${5:-$DIR}
MYSQL_PASSWORD=${6:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 ; echo '')}
MYSQL_DATABASE=${7:-$DIR}
MYSQL_ROOT_PASSWORD=${8:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 ; echo '')}
ADMIN_PASSWORD=${9:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10 ; echo '')}
EMAIL=${10:-'frank921713@hotmail.com'}

if [ "$HOST" = "dominio" ]; then
    echo no ha ingresado dominio, vuelva a ejecutar el script agregando un dominio como primer parametro
    exit 1
fi

if [ $SERVICE_NUMBER = '1' ]; then
echo "Actualizando sistema"
apt-get -y update
apt-get -y upgrade

echo "Instalando git"
apt-get -y install git-core

echo "Instalando docker"
apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get -y update
apt-get -y install docker-ce
systemctl start docker
systemctl enable docker

echo "Instalando docker compose"
curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "Instalando letsencrypt"
apt-get -y install letsencrypt
mkdir $HOME/certs/

echo "Configurando proxy"
docker network create proxynet
mkdir $HOME/proxy
cat << EOF > $HOME/proxy/docker-compose.yml
version: '3'

services:
    proxy:
        image: jwilder/nginx-proxy
        ports:
            - "80:80"
            - "443:443"
        volumes:
            - ./../certs:/etc/nginx/certs
            - /var/run/docker.sock:/tmp/docker.sock:ro
        restart: always
        privileged: true
networks:
    default:
        external:
            name: proxynet

EOF

cd $HOME/proxy
docker-compose up -d

mkdir $HOME/proxy/fpms
fi

echo "Configurando $DIR"

if ! [ -d $HOME/proxy/fpms/$DIR ]; then
echo "Cloning the repository"
rm -rf "$PATH_INSTALL/$DIR"
git clone "$PROYECT" "$PATH_INSTALL/$DIR"

mkdir $HOME/proxy/fpms/$DIR

cat << EOF > $HOME/proxy/fpms/$DIR/default
# Configuración de PHP para Nginx
server {
    listen 80 default_server;
    root /var/www/html/public;
    index index.html index.htm index.php;
    server_name *._;
    charset utf-8;
    server_tokens off;
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass fpm$SERVICE_NUMBER:9000;
    }
    error_page 404 /index.php;
    location ~ /\.ht {
        deny all;
    }
}
EOF

cat << EOF > $PATH_INSTALL/$DIR/docker-compose.yml
version: '3'

services:
    nginx$SERVICE_NUMBER:
        image: rash07/nginx
        working_dir: /var/www/html
        environment:
            VIRTUAL_HOST: $HOST, *.$HOST
        volumes:
            - ./:/var/www/html
            - $HOME/proxy/fpms/$DIR:/etc/nginx/sites-available
        restart: always
    fpm$SERVICE_NUMBER:
        image: rash07/php-fpm:1.0
        working_dir: /var/www/html
        volumes:
            - ./ssh:/root/.ssh
            - ./ssh:/var/www/.ssh
            - ./:/var/www/html
        restart: always
    mariadb$SERVICE_NUMBER:
        image: mariadb:10.5.6
        environment:
            - MYSQL_USER=\${MYSQL_USER}
            - MYSQL_PASSWORD=\${MYSQL_PASSWORD}
            - MYSQL_DATABASE=\${MYSQL_DATABASE}
            - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
            - MYSQL_PORT_HOST=\${MYSQL_PORT_HOST}
        volumes:
            - mysqldata$SERVICE_NUMBER:/var/lib/mysql
        ports:
            - "\${MYSQL_PORT_HOST}:3306"
        restart: always
    redis$SERVICE_NUMBER:
        image: redis:alpine
        volumes:
            - redisdata$SERVICE_NUMBER:/data
        restart: always
    scheduling$SERVICE_NUMBER:
        image: rash07/scheduling
        working_dir: /var/www/html
        volumes:
            - ./:/var/www/html
        restart: always

networks:
    default:
        external:
            name: proxynet

volumes:
    redisdata$SERVICE_NUMBER:
        driver: "local"
    mysqldata$SERVICE_NUMBER:
        driver: "local"

EOF

cp $PATH_INSTALL/$DIR/.env.example $PATH_INSTALL/$DIR/.env

cat << EOF >> $PATH_INSTALL/$DIR/.env


MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PORT_HOST=$MYSQL_PORT_HOST
EOF

echo "Configurando env"
cd "$PATH_INSTALL/$DIR"

sed -i "/DB_DATABASE=/c\DB_DATABASE=$MYSQL_DATABASE" .env
sed -i "/DB_PASSWORD=/c\DB_PASSWORD=$MYSQL_ROOT_PASSWORD" .env
sed -i "/DB_HOST=/c\DB_HOST=mariadb$SERVICE_NUMBER" .env
sed -i "/DB_USERNAME=/c\DB_USERNAME=root" .env
sed -i "/APP_URL_BASE=/c\APP_URL_BASE=$HOST" .env
sed -i '/APP_URL=/c\APP_URL=http://${APP_URL_BASE}' .env
sed -i '/FORCE_HTTPS=/c\FORCE_HTTPS=false' .env
sed -i '/APP_DEBUG=/c\APP_DEBUG=false' .env

#instalar certificado?
read -p "instalar con SSL? (debe tener acceso al panel de su dominio para editar/agregar records TXT). si[s] no[n] " ssl
if [ "$ssl" = "s" ]; then


    sed -i '/APP_URL=/c\APP_URL=https://${APP_URL_BASE}' .env
    sed -i '/FORCE_HTTPS=/c\FORCE_HTTPS=true' .env

    echo "Configurando certbot"
    certbot certonly --manual --preferred-challenges=dns --email $EMAIL --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d "$HOST" -d *."$HOST"

    if ! [ -f /etc/letsencrypt/live/$HOST/privkey.pem ]; then
        rm -rf "$HOME/proxy/fpms/$DIR"
        rm -rf "$PATH_INSTALL/$DIR"

        if [ $SERVICE_NUMBER = '1' ]; then
            cd $HOME/proxy

            docker-compose down

            cd $HOME
            rm -rf "$HOME/proxy"
        fi

        echo "The ssl certificate could not be generated"

        exit 1
    fi

    cp /etc/letsencrypt/live/$HOST/privkey.pem $HOME/certs/$HOST.key
    cp /etc/letsencrypt/live/$HOST/cert.pem $HOME/certs/$HOST.crt

fi

echo "Configurando archivo para usuario administrador"
mv "$PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php" "$PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php.bk"
cat << EOF > $PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php
<?php

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * @return void
     */
    public function run()
    {
        App\Models\System\User::create([
            'name' => 'Admin Instrador',
            'email' => 'admin@$HOST',
            'password' => bcrypt('$ADMIN_PASSWORD'),
        ]);
 

        DB::table('plan_documents')->insert([
            ['id' => 1, 'description' => 'Facturas, boletas, notas de débito y crédito, resúmenes y anulaciones' ],
            ['id' => 2, 'description' => 'Guias de remisión' ],
            ['id' => 3, 'description' => 'Retenciones'],
            ['id' => 4, 'description' => 'Percepciones']
        ]);

        App\Models\System\Plan::create([
            'name' => 'Ilimitado',
            'pricing' =>  99,
            'limit_users' => 0,
            'limit_documents' =>  0,
            'plan_documents' => [1,2,3,4],
            'locked' => true
        ]);

    }
}
#!/bin/bash

HOST=${1:-'dominio'}
#parametros opcionales
PROYECT=${2:-'https://gitlab.com/b.mendoza/facturadorpro3.git'}
REMOTE='git@gitlab.com:'$(echo $PROYECT | sed -e s#^https://gitlab.com/##)
SERVICE_NUMBER=${3:-'1'}
PATH_INSTALL=$(echo $HOME)
DIR=$(echo $PROYECT | rev | cut -d'/' -f1 | rev | cut -d '.' -f1)$SERVICE_NUMBER
MYSQL_PORT_HOST=${4:-'3306'}
MYSQL_USER=${5:-$DIR}
MYSQL_PASSWORD=${6:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 ; echo '')}
MYSQL_DATABASE=${7:-$DIR}
MYSQL_ROOT_PASSWORD=${8:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 ; echo '')}
ADMIN_PASSWORD=${9:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10 ; echo '')}
EMAIL=${10:-'frank921713@hotmail.com'}

if [ "$HOST" = "dominio" ]; then
    echo no ha ingresado dominio, vuelva a ejecutar el script agregando un dominio como primer parametro
    exit 1
fi

if [ $SERVICE_NUMBER = '1' ]; then
echo "Actualizando sistema"
apt-get -y update
apt-get -y upgrade

echo "Instalando git"
apt-get -y install git-core

echo "Instalando docker"
apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get -y update
apt-get -y install docker-ce
systemctl start docker
systemctl enable docker

echo "Instalando docker compose"
curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "Instalando letsencrypt"
apt-get -y install letsencrypt
mkdir $HOME/certs/

echo "Configurando proxy"
docker network create proxynet
mkdir $HOME/proxy
cat << EOF > $HOME/proxy/docker-compose.yml
version: '3'

services:
    proxy:
        image: jwilder/nginx-proxy
        ports:
            - "80:80"
            - "443:443"
        volumes:
            - ./../certs:/etc/nginx/certs
            - /var/run/docker.sock:/tmp/docker.sock:ro
        restart: always
        privileged: true
networks:
    default:
        external:
            name: proxynet

EOF

cd $HOME/proxy
docker-compose up -d

mkdir $HOME/proxy/fpms
fi

echo "Configurando $DIR"

if ! [ -d $HOME/proxy/fpms/$DIR ]; then
echo "Cloning the repository"
rm -rf "$PATH_INSTALL/$DIR"
git clone "$PROYECT" "$PATH_INSTALL/$DIR"

mkdir $HOME/proxy/fpms/$DIR

cat << EOF > $HOME/proxy/fpms/$DIR/default
# Configuración de PHP para Nginx
server {
    listen 80 default_server;
    root /var/www/html/public;
    index index.html index.htm index.php;
    server_name *._;
    charset utf-8;
    server_tokens off;
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass fpm$SERVICE_NUMBER:9000;
    }
    error_page 404 /index.php;
    location ~ /\.ht {
        deny all;
    }
}
EOF

cat << EOF > $PATH_INSTALL/$DIR/docker-compose.yml
version: '3'

services:
    nginx$SERVICE_NUMBER:
        image: rash07/nginx
        working_dir: /var/www/html
        environment:
            VIRTUAL_HOST: $HOST, *.$HOST
        volumes:
            - ./:/var/www/html
            - $HOME/proxy/fpms/$DIR:/etc/nginx/sites-available
        restart: always
    fpm$SERVICE_NUMBER:
        image: rash07/php-fpm:1.0
        working_dir: /var/www/html
        volumes:
            - ./ssh:/root/.ssh
            - ./ssh:/var/www/.ssh
            - ./:/var/www/html
        restart: always
    mariadb$SERVICE_NUMBER:
        image: mariadb:10.5.6
        environment:
            - MYSQL_USER=\${MYSQL_USER}
            - MYSQL_PASSWORD=\${MYSQL_PASSWORD}
            - MYSQL_DATABASE=\${MYSQL_DATABASE}
            - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
            - MYSQL_PORT_HOST=\${MYSQL_PORT_HOST}
        volumes:
            - mysqldata$SERVICE_NUMBER:/var/lib/mysql
        ports:
            - "\${MYSQL_PORT_HOST}:3306"
        restart: always
    redis$SERVICE_NUMBER:
        image: redis:alpine
        volumes:
            - redisdata$SERVICE_NUMBER:/data
        restart: always
    scheduling$SERVICE_NUMBER:
        image: rash07/scheduling
        working_dir: /var/www/html
        volumes:
            - ./:/var/www/html
        restart: always

networks:
    default:
        external:
            name: proxynet

volumes:
    redisdata$SERVICE_NUMBER:
        driver: "local"
    mysqldata$SERVICE_NUMBER:
        driver: "local"

EOF

cp $PATH_INSTALL/$DIR/.env.example $PATH_INSTALL/$DIR/.env

cat << EOF >> $PATH_INSTALL/$DIR/.env


MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PORT_HOST=$MYSQL_PORT_HOST
EOF

echo "Configurando env"
cd "$PATH_INSTALL/$DIR"

sed -i "/DB_DATABASE=/c\DB_DATABASE=$MYSQL_DATABASE" .env
sed -i "/DB_PASSWORD=/c\DB_PASSWORD=$MYSQL_ROOT_PASSWORD" .env
sed -i "/DB_HOST=/c\DB_HOST=mariadb$SERVICE_NUMBER" .env
sed -i "/DB_USERNAME=/c\DB_USERNAME=root" .env
sed -i "/APP_URL_BASE=/c\APP_URL_BASE=$HOST" .env
sed -i '/APP_URL=/c\APP_URL=http://${APP_URL_BASE}' .env
sed -i '/FORCE_HTTPS=/c\FORCE_HTTPS=false' .env
sed -i '/APP_DEBUG=/c\APP_DEBUG=false' .env

#instalar certificado?
read -p "instalar con SSL? (debe tener acceso al panel de su dominio para editar/agregar records TXT). si[s] no[n] " ssl
if [ "$ssl" = "s" ]; then


    sed -i '/APP_URL=/c\APP_URL=https://${APP_URL_BASE}' .env
    sed -i '/FORCE_HTTPS=/c\FORCE_HTTPS=true' .env

    echo "Configurando certbot"
    certbot certonly --manual --preferred-challenges=dns --email $EMAIL --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d "$HOST" -d *."$HOST"

    if ! [ -f /etc/letsencrypt/live/$HOST/privkey.pem ]; then
        rm -rf "$HOME/proxy/fpms/$DIR"
        rm -rf "$PATH_INSTALL/$DIR"

        if [ $SERVICE_NUMBER = '1' ]; then
            cd $HOME/proxy

            docker-compose down

            cd $HOME
            rm -rf "$HOME/proxy"
        fi

        echo "The ssl certificate could not be generated"

        exit 1
    fi

    cp /etc/letsencrypt/live/$HOST/privkey.pem $HOME/certs/$HOST.key
    cp /etc/letsencrypt/live/$HOST/cert.pem $HOME/certs/$HOST.crt

fi

echo "Configurando archivo para usuario administrador"
mv "$PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php" "$PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php.bk"
cat << EOF > $PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php
<?php

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * @return void
     */
    public function run()
    {
        App\Models\System\User::create([
            'name' => 'Admin Instrador',
            'email' => 'admin@$HOST',
            'password' => bcrypt('$ADMIN_PASSWORD'),
        ]);
 

        DB::table('plan_documents')->insert([
            ['id' => 1, 'description' => 'Facturas, boletas, notas de débito y crédito, resúmenes y anulaciones' ],
            ['id' => 2, 'description' => 'Guias de remisión' ],
            ['id' => 3, 'description' => 'Retenciones'],
            ['id' => 4, 'description' => 'Percepciones']
        ]);

        App\Models\System\Plan::create([
            'name' => 'Ilimitado',
            'pricing' =>  99,
            'limit_users' => 0,
            'limit_documents' =>  0,
            'plan_documents' => [1,2,3,4],
            'locked' => true
        ]);

    }
}

EOF

echo "Configurando proyecto"
docker-compose up -d
docker-compose exec -T fpm$SERVICE_NUMBER rm composer.lock
docker-compose exec -T fpm$SERVICE_NUMBER composer self-update
docker-compose exec -T fpm$SERVICE_NUMBER composer install
docker-compose exec -T fpm$SERVICE_NUMBER php artisan migrate:refresh --seed
docker-compose exec -T fpm$SERVICE_NUMBER php artisan key:generate
docker-compose exec -T fpm$SERVICE_NUMBER php artisan storage:link

rm $PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php
mv $PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php.bk $PATH_INSTALL/$DIR/database/seeds/DatabaseSeeder.php

echo "configurando permisos"
chmod -R 777 "$PATH_INSTALL/$DIR/storage/" "$PATH_INSTALL/$DIR/bootstrap/" "$PATH_INSTALL/$DIR/vendor/"
chmod +x $PATH_INSTALL/$DIR/script-update.sh

#Configurar clave ssh
read -p "configurar clave SSH para actualización automática? (requiere acceso a https://gitlab.com/profile/keys). si[s] no[n] " ssh
if [ "$ssh" = "s" ]; then

    echo "generando clave SSH"
    ssh-keygen -t rsa -q -P "" -f $PATH_INSTALL/$DIR/ssh/id_rsa
    echo "cambiando remote"
    git remote set-url origin $REMOTE

    ssh-keyscan -H gitlab.com >> $PATH_INSTALL/$DIR/ssh/known_hosts

    docker-compose exec -T fpm$SERVICE_NUMBER chown -R www-data ssh/
    docker-compose exec -T fpm$SERVICE_NUMBER chown -R www-data /var/www/
fi

echo "Ruta del proyecto dentro del servidor: $HOME/$DIR"
echo "URL: $HOST"
echo "Correo para administrador: admin@$HOST"
echo "Contraseña para administrador: $ADMIN_PASSWORD"
echo "Clave SSH para añadir en gitlab"
cat $PATH_INSTALL/$DIR/ssh/id_rsa.pub

else
echo "La carpeta $HOME/proxy/fpms/$DIR ya existe"
fi
