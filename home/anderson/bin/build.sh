#!/bin/bash

BASE_DIR="/home/anderson/dataprev"
PROJECT=$1
shift  # Remove o primeiro argumento ($1) e move os demais para a esquerda
FLAGS=("$@")  # Captura todas as flags restantes em um array

# Determinar o AMBIENTE padrão (local) e sobrescrever se uma flag correspondente for encontrada
AMBIENTE="local"
for FLAG in "${FLAGS[@]}"; do
    case "$FLAG" in
        "dev"|"homol"|"prod")
            AMBIENTE="$FLAG"
            ;;
    esac
done

case "$PROJECT" in
    "meu-inss-service" | "inss-notificacoes-registro-api" | "inss-notificacoes-batch" | \
    "inss-notificacoes-commons" | "inss-notificacoes-api" | "inss-notificacoes-config-api")
        export PATH=$JAVA_8:$PATH
        ;;

    "meu-inss-gateway" | "meu-inss-gestao-api")
        export PATH=$JAVA_21:$PATH
        ;;

    "meu-inss-mobile")
        for FLAG in "${FLAGS[@]}"; do
            case "$FLAG" in
                "v35")
                    echo "Build v35..."
                    cd "$BASE_DIR/central-servico-react" || exit 1
                    npm i --legacy-peer-deps
                    npm run "android:${AMBIENTE}" || exit 1

                    rm -R "$BASE_DIR/meu-inss-mobile/www/v35"
                    mkdir "$BASE_DIR/meu-inss-mobile/www/v35"
                    cp -R "$BASE_DIR/central-servico-react/public/"* "$BASE_DIR/meu-inss-mobile/www/v35"
                    ;;
                "v5")
                    echo "Build v5..."
                    cd "$BASE_DIR/meu-inss-internet" || exit 1
                    npm i --legacy-peer-deps
                    npm run "android:${AMBIENTE}" || exit 1

                    cd "$BASE_DIR/meu-inss-mobile/www" || exit
                    find . -maxdepth 1 -mindepth 1 ! -name "v35" -exec rm -r {} \;
                    cp -R "$BASE_DIR/meu-inss-internet/build/"* "$BASE_DIR/meu-inss-mobile/www"
                    ;;
                "local")
                    echo "Configurando ambiente local..."
                    sed -i -e "s/localhost/10.0.2.2/g" "$BASE_DIR/meu-inss-mobile/www/v35/config/env.js"
                    sed -i -e "s/localhost/10.0.2.2/g" "$BASE_DIR/meu-inss-mobile/www/config/env.js"
                    ;;
                "clean")
                    echo "Limpando projeto..."
		    cd "$BASE_DIR/meu-inss-mobile/" || exit 1
                    rm -Rf "plugins"
                    rm -Rf "platforms"
                    npm i --legacy-peer-deps
                    cordova prepare android
                    ;;
                *)
                    echo "Warning: Unknown flag '$FLAG'"
                    ;;
            esac
        done

        cd "$BASE_DIR/meu-inss-mobile/" || exit
	echo "Gerando APK..."
        cordova build android --release -- --keystore=$MEU_INSS_KEYSTORE --storePassword=$MEU_INSS_STORE_PASSWORD --alias=$MEU_INSS_ALIAS --password=$MEU_INSS_PASSWORD --packageType=apk
	thunar "$BASE_DIR/meu-inss-mobile/platforms/android/app/build/outputs/apk/release"
        exit 0
        ;;

    *)
        echo "Projeto $PROJECT não encontrado!"
        exit 1
        ;;
esac

java -version
cd "$BASE_DIR/$PROJECT/" || exit
mvn clean install -DskipTests

