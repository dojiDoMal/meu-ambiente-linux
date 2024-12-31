#!/bin/bash

if [ "$1" == "meu-inss-service" ]; then
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/meu-inss-service/ || exit
    mvn clean install -DskipTests

elif [ "$1" == "inss-notificacoes-commons" ]; then
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/inss-notificacoes/inss-notificacoes-commons/ || exit
    mvn clean install -DskipTests

elif [ "$1" == "inss-notificacoes-api" ]; then
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/inss-notificacoes/inss-notificacoes-api/ || exit
    mvn clean install -DskipTests

elif [ "$1" == "inss-notificacoes-config-api" ]; then
    export PATH=$JAVA_8:$PATH
    java -version
    cd /home/anderson/dataprev/inss-notificacoes/inss-notificacoes-config-api/ || exit
    mvn clean install -DskipTests

elif [ "$1" == "meu-inss-gateway" ]; then
    export PATH=$JAVA_17:$PATH
    java -version
    cd /home/anderson/dataprev/meu-inss-gateway/ || exit
    mvn clean install -DskipTests

elif [ "$1" == "meu-inss-gestao-api" ]; then
    export PATH=$JAVA_21:$PATH
    java -version
    cd /home/anderson/dataprev/meu-inss-gestao-api/ || exit
    mvn clean install -DskipTests

else
    echo "Unknown project: $1"
fi
