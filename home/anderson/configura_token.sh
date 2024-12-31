#!/bin/bash

#############################################################################################################
# Script utilizado para configurar o token de certificado A3
# Esse script baixa e instala os certificados do ICP Brasil, instala o driver do token A3 e os aplicativos necessários
# Após a instalação do driver, será necessário executar alguns passos manuais para verificar a configuralção no Firefox
# Nota: Esse script funciona apenas com gerenciador de pacotes da família Debian e Token A3 da Soluti (Safenet) ou SafeSign
#############################################################################################################

# Comandos p11tool
# Lista as URLs dos tokens
#p11tool --list-token-urls
# Lista as URLs dos tokens Físicos
#p11tool --list-token-urls | grep --invert-match 'System'
# Lista os certificados dos tokens
#p11tool --list-all-certs <URL>
# Lista os certificados do usuário, do primeiro token físico
#p11tool --list-token-urls | grep --invert-match 'System' | xargs p11tool --list-all-certs | grep -oP 'URL:.*%3A.*' | cut -c6-

# *** Token GD com Ubuntu 18.* ***
# 1 - Comentar o donwload e instalação do libsslv1 no método: do_instala_libsslv1() pois a mesma existe no repositório oficial
# 2 - Instalar a libsslv1.1 utilizando o apt-get manualmente
# 3 - Seguir com a instalação normalmente

# Nome do script em execução (Suporta aspas e link simbólico)
TOKEN_SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")

URL_DRIVER_SAFENET="https://www.globalsign.com/en/safenet-drivers/USB/10.7/Safenet_Linux_Installer_DEB_x64.zip"
URL_DRIVER_SAFESIGN="https://safesign.gdamericadosul.com.br/content/SafeSign_IC_Standard_Linux_3.7.0.0_AET.000_ub2004_x86_64.rar"
URL_DRIVER_EPASS2003='https://docs.google.com/uc?export=download&id=1taXWF9eZgrhHtU76XpRqGeRzYcvKDnOX'

URL_LIB_SSL1="http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb"
URL_LIB_WXW_BASE=http://archive.ubuntu.com/ubuntu/pool/universe/w/wxwidgets3.0/libwxbase3.0-0v5_3.0.4+dfsg-15build1_amd64.deb
URL_LIB_WXWIDGETS=http://archive.ubuntu.com/ubuntu/pool/universe/w/wxwidgets3.0/libwxgtk3.0-gtk3-0v5_3.0.4+dfsg-15build1_amd64.deb
URL_LIB_TIFF5=http://archive.ubuntu.com/ubuntu/pool/main/t/tiff/libtiff5_4.1.0+git191117-2build1_amd64.deb
URL_LIB_WEBP6=http://archive.ubuntu.com/ubuntu/pool/main/libw/libwebp/libwebp6_0.6.1-2ubuntu0.20.04.3_amd64.deb


# Carrega o script com as funções básicas
SCRIPT_FUNCTIONS="$(readlink -f "${BASH_SOURCE[0]}" | xargs -d '\n' dirname)/functions.sh"
if [[ ! -f "${SCRIPT_FUNCTIONS}" ]]; then
    echo -e "\e[31;1mO script ${SCRIPT_FUNCTIONS} é necessário para a execução desse script\e[m\n"
    exit 1
else
    #shellcheck source=functions.sh
    . "${SCRIPT_FUNCTIONS}"
fi

#Exibe o usage do script
do_show_usage() {
    echo "Script de configuração do token de certificado"
    echo ""
    echo "Uso: ${TOKEN_SCRIPT_NAME} "
    echo ""
    echo "    Opções:"
    echo ""
    echo "    -h                 Imprime esta página de ajuda."
    exit 0
}

# Verifica os parâmetros informados na inicialização do script
do_check_settings() {
    local short_options=h
    local long_options=help
    local parsed_options
    parsed_options=$(getopt --options "${short_options}" --longoptions "${long_options}" --name "${0}" -- "$@") || exit $?
    eval set -- "${parsed_options}"
    while true; do
        case "${1}" in
        -h | --help)
            do_show_usage
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Parâmetro desconhecido"
            exit 3
            ;;
        esac
    done

    #Verifica se a distro é baseada em Debian
    do_ensure_debian

    # Verifica as ferramentas necessárias
    apps=("whiptail" "keytool" "curl" "unrar" "tar")
    do_check_apps "${apps[@]}"

    do_verifica_firefox_snap

    #Verifica se o usuário pode ser root
    do_ensure_sudo
}

do_verifica_firefox_snap() {
    do_check_app "firefox"

    # Verifica se o firefox foi instalado pelo SNAP
    firefox_path=$(ls -l $(which firefox))
    if [[ $firefox_path == *snap ]]; then
        echo ""
        do_show_warn "Importante:"
        do_show_warn "O firefox que está no path foi instalado usando o SNAP e não irá conseguir acessar as bibliotecas do token."
        do_show_warn "Para utilizar o token no firefox e no chrome, será necessário:"
        do_show_warn " - Instalar manualmente o firefox a partir do download do arquivo do site da mozilla.org "
        do_show_warn " - Adicionar o caminho do binário desse firefox nativo, na variável de ambiente PATH, antes do diretório /snap/bin"
        do_show_warn " - Fechar e abrir o terminal, para recarregar o valor da variável PATH"
        do_show_warn " - Rodar esse script novamente"
        echo ""
        exit 1
    fi
}

do_download_and_extract_driver() {
    local url="${1}"
    local temp_file="${2}"
    local temp_dir="/tmp/token"
    echo ""
    echo " - Efetuando o dowload do driver"
    echo ""

    do_download_temp_file "${url}" "${temp_file}"

    sudo rm -rf "${temp_dir}" 2>/dev/null
    sudo mkdir "${temp_dir}"

    echo " - Extraindo o arquivo baixado"
    echo ""

    if [[ $temp_file == *zip ]]; then
        # Extrai o zip
        sudo unzip "${temp_file}" -d "${temp_dir}" >/dev/null || do_show_error "Erro: Falha ao extrair o arquivo [${temp_file}] para [${temp_dir}]"
    elif [[ $temp_file == *tar.gz ]]; then
        # Extrai o tar.gz
        sudo tar zxf "${temp_file}" -C "${temp_dir}/" &>/dev/null || do_show_error "Erro: Falha ao extrair o arquivo [${temp_file}] para [${temp_dir}]"
    elif [[ $temp_file == *rar ]]; then
        # Extrai o rar
        sudo unrar x "${temp_file}" "${temp_dir}" >/dev/null || do_show_error "Erro: Falha ao extrair o arquivo [${temp_file}] para [${temp_dir}]"
    else
        do_show_error "Erro: Extração de arquivo no formato não mapeado - ${temp_file}"
    fi
}

do_install_deb_driver() {
    local temp_dir="/tmp/token"
    echo " - Instalando os arquivo *64*.deb"
    echo ""
    # Instala os pacotes do driver
    while IFS= read -r -d $'\0'; do
        local deb_file="${REPLY}"
        sudo dpkg -i "${deb_file}" || do_show_error "Falhou ao instalar o driver do token: ${deb_file}"
    done < <(sudo find ${temp_dir} -name '*64*.deb' -type f -print0)

}

do_download_and_install_libs() {
    echo ""
    echo " - Instalando bibliotecas e aplicativos utilizados pelo token"
    echo ""
    # Instala os aplicativos de smartcard
    sudo apt-get install -y pcscd libccid libpcsclite1 pcsc-tools libnss3-tools gnutls-bin libssl-dev opensc || do_show_error "Falhou ao instalar os pacotes: pcscd libccid libpcsclite1 pcsc-tools libnss3-tools gnutls-bin libssl-dev"

    # Reinicia o serviço do pcscd (smartcard)
    sudo systemctl restart pcscd.service || do_show_error "Falhou ao reiniciar o serviço pcscd.service"
    sudo systemctl enable pcscd.service

    # Configura o driver do token como padrão do pcscd
    sudo ln -s /usr/lib/libeToken.so /usr/lib/x86_64-linux-gnu/pkcs11/opensc-pkcs11.so 2>/dev/null

    echo ""
    echo " - Verificando comunicação do driver com o p11-tools"
    echo ""
    pkcs11-tool --module /usr/lib/libeToken.so -O || do_show_error "Falha na comunicação do p11-tools com o driver do token. O token está conectado no USB?"

    echo ""
    echo -e "\e[1;33mNota: abaixo pode ser exibida uma mensagem de Failure to load dynamic library, mas a comunicação com o token ocorreu com sucesso e essa mensagem pode ser ignorada!\e[0m"

    # Configura o GNU-TLS (usado pelo openconnect)
    echo ""
    echo " - Criando configuração do GNU-TLS (usado pelo openconnect)"
    sudo mkdir /etc/pkcs11 2>/dev/null
    sudo mkdir /etc/pkcs11/modules 2>/dev/null
    echo 'module: /usr/lib/libeToken.so' >eToken.module
    sudo mv eToken.module /etc/pkcs11/modules 2>/dev/null

    echo ""
    echo " - Criando o arquivo chaveiro do Mozilla Firefox (também utilizado pelo chrome)"
    local previous_dir="${PWD}"
    cd "${HOME}/" 2>/dev/null || do_show_error "Falha ao tentar acessar o diretório ${HOME}"
    modutil -force -dbdir sql:.pki/nssdb/ -add "eToken" -libfile /usr/lib/libeToken.so

    # Mudando o owner dos arquivos do chaveiro para o usuário
    sudo chown -R "${USER}":"${USER}" "${HOME}/.pki"

    cd "${previous_dir}" || do_show_error "Falha ao retornar para o diretório ${previous_dir}"
}

do_instala_libsslv1() {
    # As versões mais novas do Ubuntu utilizam libssl v3, mas os drivers dos tokens utiliza a v1
    echo ""
    echo ""
    echo " - Efetuando o dowload e instalando a libssl v1, necessária para o driver do token"
    echo "URL: ${URL_LIB_SSL1}"
    wget --no-check-certificate "${URL_LIB_SSL1}" -O "/tmp/libsslv1.deb"
    if [[ $? -ne 0 ]]; then
        url_lib_ssl1=$(curl http://security.ubuntu.com/ubuntu/pool/main/o/openssl/ | grep -oP '>libssl1.1_.*_amd64.deb' | cut -c2- | tail -1)
        echo "Tentando fazer o download da biblioteca usando a URL ${url_lib_ssl1}"
        wget --no-check-certificate "${url_lib_ssl1}" -O "/tmp/libsslv1.deb"
    fi

    [[ -f /tmp/libsslv1.deb ]] || do_show_error "Falhou no donwload da biblioteca libsslv1"
    sudo dpkg -i /tmp/libsslv1.deb
}

do_instala_wxwidgets() {
    # O Ubuntu 24.04 removeu a libwxgtk3.0-gtk3-0v5 do repositorio oficial   

    if [[ -n $(apt seach libwxgtk3.0-gtk3-0v5) ]]; then
        echo ""
        echo "Instalando libwxbase3.0-0v5 de ${URL_LIB_WXW_BASE}"
        echo ""
        wget --no-check-certificate "${URL_LIB_WXW_BASE}" -O "/tmp/libwxbase3.deb"
        [[ -f /tmp/libwxbase3.deb ]] || do_show_error "Falhou no donwload da biblioteca libwxbase3.0-0v5"
        sudo dpkg -i /tmp/libwxbase3.deb

        echo ""
        echo "Instalando libwebp6 de ${URL_LIB_WEBP6}"
        echo ""
        wget --no-check-certificate "${URL_LIB_WEBP6}" -O "/tmp/libwebp6.deb"
        [[ -f /tmp/libwebp6.deb ]] || do_show_error "Falhou no donwload da biblioteca libwebp6"
        sudo dpkg -i /tmp/libwebp6.deb

        echo ""
        echo "Instalando libtiff5 de ${URL_LIB_TIFF5}"
        echo ""
        wget --no-check-certificate "${URL_LIB_TIFF5}" -O "/tmp/libtiff5.deb"
        [[ -f /tmp/libtiff5.deb ]] || do_show_error "Falhou no donwload da biblioteca libtiff5"
        sudo dpkg -i /tmp/libtiff5.deb

        echo ""
        echo "Instalando libwxgtk3.0-gtk3-0v5 de ${URL_LIB_WXWIDGETS}"
        echo ""
        wget --no-check-certificate "${URL_LIB_WXWIDGETS}" -O "/tmp/libwxgtk3.deb"
        [[ -f /tmp/libwxgtk3.deb ]] || do_show_error "Falhou no donwload da biblioteca libwxgtk3.0-gtk3-0v5"
        sudo dpkg -i /tmp/libwxgtk3.deb
    else 
        echo "Instalando libwxgtk3.0-gtk3-0v5..."
        sudo apt-get -y install libwxgtk3.0-gtk3-0v5
    fi
}

# Efetua o download e instala o driver do SafeNet
do_download_and_install_safenet() {
    echo " - Garante que o pixbuf está instalado"
    sudo apt-get -y install libgdk-pixbuf2.0-0 libgdk-pixbuf2.0-common

    # Download e instala o driver
    do_download_and_extract_driver "${URL_DRIVER_SAFENET}" "/tmp/safenet.zip"
    do_install_deb_driver

    # Reinicia o serviço do SafeNet
    sudo systemctl restart SACSrv.service
}

# Efetua o download e instala o driver do ePass2003
do_download_and_install_epass2003() {
    echo " - Efetuando o download do driver"
    do_download_and_extract_driver "${URL_DRIVER_EPASS2003}" "/tmp/ePass2003.tar.gz"

    echo " - Removendo qualquer instalação anterior"
    sudo rm -f /tmp/ePass2003-Linux-x64/ 2>/dev/null
    sudo rm -f /usr/lib/ePass2003-Linux-x64/ 2>/dev/null

    echo " - Copiando driver para /usr/lib"
    sudo mv /tmp/token/ePass2003-Castle-20141128/ /tmp/ePass2003-Linux-x64/
    sudo cp -rf /tmp/ePass2003-Linux-x64/ /usr/lib/

    echo " - Criando links das aplicações e bibliotecas"
    sudo sh /usr/lib/ePass2003-Linux-x64/x86_64/config/config.sh
    sudo cp /usr/lib/ePass2003-Linux-x64/x86_64/redist/libcastle.so.1.0.0 /usr/lib
    sudo ln -s /usr/lib/ePass2003-Linux-x64/x86_64/redist/pkimanager_admin /bin/pkimanager_admin
    sudo chmod 777 /usr/lib/ePass2003-Linux-x64/x86_64/redist/pkimanager_admin

    # Cria um link da lib do SafeSign com o mesmo nome da lib do safenet, para padronizar a instalação
    sudo rm -f /usr/lib/libeToken.so 2>/dev/null
    sudo ln -s /usr/lib/ePass2003-Linux-x64/x86_64/redist/libcastle.so.1.0.0 /usr/lib/libeToken.so

    #    sudo pkimanager_admin
}

do_download_and_install_safesign() {
    echo " - Garante que o pixbuf está instalado"
    sudo apt-get -y install libgdk-pixbuf2.0-0 libgdk-pixbuf2.0-common libtiff5-dev pcscd

    echo " - Efetua o download e instala o driver e a biblioteca do wxWidgets (necessário para o FrontEnd do driver)"
    do_instala_wxwidgets

    # Download e instala o driver
    do_download_and_extract_driver "${URL_DRIVER_SAFESIGN}" "/tmp/safesign.rar"
    do_install_deb_driver

    # Cria um link da lib do SafeSign com o mesmo nome da lib do safenet, para padronizar a instalação
    sudo rm -f /usr/lib/libeToken.so 2>/dev/null
    sudo ln -s /usr/lib/libaetpkss.so /usr/lib/libeToken.so
}

do_remove_drivers_token() {
    echo " - Removendo possíveis drivers instalados anteriormente"

    # Safenet
    sudo apt-get purge -y safenetauthenticationclient

    # SafeSign
    sudo apt-get purge -y safesignidentityclient
}

##############################
# Main
##############################

do_check_settings "$@"
opcoes=()
opcoes+=("SafeNet 5110" "Token Verde / AC Soluti" "ON")
opcoes+=("SafeSign GD" "Token Preto / AC CertiSign" "OFF")
opcoes+=("ePass2003 Feitian" "Token com logo verde da Soluti" "OFF")

token="$(whiptail --backtitle "Qual o token a ser configurado" --title "Seleção do token" --ok-button="Continuar" --cancel-button="Sair" --radiolist "Selecione o tipo do token abaixo" 20 65 "${#opcoes[@]}" "${opcoes[@]}" 3>&1 1>&2 2>&3)"
do_check_selection "${token}"

# Instala a libssl v1 (necessária para todos os tokens)
do_instala_libsslv1
do_remove_drivers_token

if [[ "SafeNet 5110" == "${token}" ]]; then
    # Instala o driver do SafeNet
    do_download_and_install_safenet
elif [[ "ePass2003 Feitian" == "${token}" ]]; then
    # Instala o driver do ePass2003
    do_download_and_install_epass2003
else
    # Instala o driver do SafeSign
    do_download_and_install_safesign
fi

# Download e instala as outras libs e utilitários necessários
do_download_and_install_libs

# Efetua o donwload da cadeia de certificados da CA
do_download_cadeia_certificados
# Configura a cadeia de certificados e o token no Firefox
do_instala_certificados_firefox
