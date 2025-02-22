#!/bin/bash

# Carregar nvm se não estiver carregado
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    \. "$HOME/.nvm/nvm.sh"
fi

if [ "$1" == "meu-inss-service" ]; then
    echo -e "\033]0;meu-inss-service\007"
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/meu-inss-service/ || exit
    java -jar target/meu-inss-service.jar

elif [ "$1" == "inss-notificacoes-registro-api" ]; then
    echo -e "\033]0;inss-notificacoes-registro-api\007"
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/inss-notificacoes/inss-notificacoes-registro-api/ || exit
    java -jar target/inss-notificacoes-registro-api.jar

elif [ "$1" == "inss-notificacoes-batch" ]; then
    echo -e "\033]0;inss-notificacoes-batch\007"
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/inss-notificacoes/inss-notificacoes-batch/ || exit
    java -jar target/inss-notificacoes-batch.jar

elif [ "$1" == "inss-notificacoes-api" ]; then
    echo -e "\033]0;inss-notificacoes-api\007"
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/inss-notificacoes/inss-notificacoes-api/ || exit
    java -jar target/inss-notificacoes-api.jar

elif [ "$1" == "inss-notificacoes-config-api" ]; then
    echo -e "\033]0;inss-notificacoes-config-api\007"
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/inss-notificacoes/inss-notificacoes-config-api/ || exit
    java -jar target/inss-notificacoes-config-api.jar

elif [ "$1" == "meu-inss-gateway" ]; then
    echo -e "\033]0;meu-inss-gateway\007"
    export PATH=$JAVA_21:$PATH
    java -version
    cd /home/anderson/dataprev/meu-inss-gateway/ || exit
    java -jar target/meu-inss-gateway.jar

elif [ "$1" == "meu-inss-gestao-api" ]; then
    echo -e "\033]0;meu-inss-gestao-api\007"
    export PATH=$JAVA_21:$PATH
    java -version
    cd /home/anderson/dataprev/meu-inss-gestao-api/ || exit
    java -jar target/meu-inss-gestao-api.jar

elif [ "$1" == "portal-spa" ]; then
    echo -e "\033]0;portal-spa\007"
    nvm use 13
    cd /home/anderson/dataprev/portal-spa/ || exit
    npm run start-linux

elif [ "$1" == "central-servico-react" ]; then
    echo -e "\033]0;central-servico-react\007"
    nvm use 16
    cd /home/anderson/dataprev/central-servico-react/ || exit
    npm run start

elif [ "$1" == "meu-inss-internet" ]; then
    echo -e "\033]0;meu-inss-internet\007"
    nvm use 20
    cd /home/anderson/dataprev/meu-inss-internet/ || exit
    npm run start

elif [ "$1" == "meu-inss-gestao-spa" ]; then
    echo -e "\033]0;meu-inss-gestao-spa\007"
    nvm use 20
    cd /home/anderson/dataprev/meu-inss-gestao-spa/ || exit
    npm run start

else
    echo "Unknown project: $1"
fi

