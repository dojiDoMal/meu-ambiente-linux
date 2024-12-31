#!/bin/bash

###########################################################################################################
# Script de configuração da VPN da dataprev
# O script instalar os pre-requisitos, compilar e criar um alias para facilitar o uso da VPN
############################################################################################################

# Comandos p11tool

# Lista as URLs dos tokens
#p11tool --list-token-urls

# Lista as URLs dos tokens Físicos
#p11tool --list-token-urls | grep --invert-match 'p11-kit-trust'

# Lista os certificados dos tokens
#p11tool --list-all-certs <URL>

# Lista os certificados do usuário, do primeiro token físico
#p11tool --list-token-urls | grep --invert-match 'p11-kit-trust' | xargs p11tool --list-all-certs | grep -oP 'URL:.*%3A.*' | cut -c6-

#Nome do script em execução (Suporta aspas e link simbólico)
SCRIPT_NAME_VPN=$(basename "${BASH_SOURCE[0]}")

# Carrega o script com as funções básicas
SCRIPT_FUNCTIONS="$(readlink -f "${BASH_SOURCE[0]}" | xargs -d '\n' dirname)/functions.sh"
if [[ ! -f "${SCRIPT_FUNCTIONS}" ]]; then
    echo -e "\e[31;1mO script ${SCRIPT_FUNCTIONS} é necessário para a execução desse script\e[m\n"
    exit 1
else
    #shellcheck source=functions.sh
    . "${SCRIPT_FUNCTIONS}"
fi

# Caminho dos arquivos que serão criados
PATH_VPN_SH="${DIR_NAME_VPN}/vpn.sh"
PATH_CERTIFICADOS_PEM="${DIR_NAME_VPN}/certificados.pem"

#Exibe o usage do script
do_show_usage() {
    echo -e "Script de configuração da VPN\n"

    echo "uso: ${SCRIPT_NAME_VPN} [OPÇÕES...]"
    echo "ex.: bash ${SCRIPT_NAME_VPN}"
    echo ""
    echo "    Opções:"
    echo ""
    echo "    -h                      Imprime esta página de ajuda."
    echo ""
    exit 0
}

# Verifica os parâmetros informados na inicialização do script
do_check_settings() {
    local short_options=h,
    local long_options=help,
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
            echo "Parâmetro desconhecido: ${1}"
            exit 3
            ;;
        esac
    done

    # Verifica as ferramentas necessárias
    apps=("whiptail" "java" "keytool" "wget" "curl" "nc" "openconnect" "p11tool")
    do_check_apps "${apps[@]}"

    # Verifica a versão instalada do OpenConnect
    local version
    version=$(openconnect --version | grep -oP 'version v[0-9\.]+' | cut -c10-)
    if (($(echo "${version} < 8.0" | bc -l))); then
        do_show_error "Erro: A versão instalada do OpenConnect deve ser maior do que a 8.0 para suportar o protocolo Global Protect"
    fi

    #Verifica se o usuário pode ser root
    do_ensure_sudo

    # Verifica o diretório do script vpn
    [[ -d "${DIR_NAME_VPN}" ]] || do_show_error "É necessário rodar antes o script configura_token.sh"
}

##############################
# Main
##############################

do_check_settings "$@"

##############
# Solicita o login do usuário
##############

[[ -f "${PATH_VPN_SH}" ]] && login=$(grep -oP '[^\s]+@dataprev.gov.br' < "${PATH_VPN_SH}" | cut -d@ -f1)
[[ -z "${login}" ]] && login=${USER}
do_ask_question "Login do LDAP:" "${login}" "Por favor, informe o Login do LDAP:"

# Captura apenas o login, se o usuário informou o e-mail
login_ldap=$(echo "${ANSWER}" | grep -oP '[^@]+' | head -1)

##############
# Seleciona o Gateway e o servidor
##############

opcoes=()
opcoes+=("GW_EXT_DCSP_A3" "vpncertsp.dataprev.gov.br" "ON")
opcoes+=("GW_EXT_DCDF_A3" "vpncertdf.dataprev.gov.br" "OFF")
opcoes+=("GW_EXT_DCDF_A3" "portalvpncert.dataprev.gov.br" "OFF")
#opcoes+=("GW_EXT_DCRJ_A3" "vpncertrj.dataprev.gov.br" "OFF")
#Nota: portalvpncert.dataprev.gov.br redireciona para vpndfcert.dataprev.gov.br
#vpndfcert.dataprev.gov.br
#vpnrjcert.dataprev.gov.br
#vpncertsp.dataprev.gov.br
#vpnrj.dataprev.gov.br
#vpndf.dataprev.gov.br

# Recupera o gateway e o servidor da VPN
gateway="$(whiptail --backtitle "Qual a gateway a ser utilizado" --title "Seleção do Gateway" --ok-button="Continuar" --cancel-button="Sair" --radiolist "Selecione o gateway que deve ser usado pela VPN" 30 60 "${#opcoes[@]}" "${opcoes[@]}" 3>&1 1>&2 2>&3)"
index=$(echo "${opcoes[@]/$gateway//}" | cut -d/ -f1 | wc -w | tr -d ' ')
gateway="--authgroup=${gateway}"
SERVER_VPN="${opcoes[($index+1)]}"

##############
# Verifica a conectividade com o servidor selecionado
##############

echo ""
echo "Verificando a conectividade com o servidor da VPN: ${SERVER_VPN}"
[[ "$(nc -z -v -w2 "${SERVER_VPN}" 443)" ]] && do_show_error "Falha ao se comunicar com o servidor ${SERVER_VPN} na porta 443"
[[ "$(nc -z -u -v -w2 "${SERVER_VPN}" 4501)" ]] && do_show_error "Falha ao se comunicar com o servidor ${SERVER_VPN} na porta 4501"

##############
# Captura os detalhes dos certificados do token
##############

# Verifica a URL do token
echo ""
echo "Consultando dados dos certificados disponíveis do token"
url_token=$(p11tool --list-token-urls | grep --invert-match 'p11-kit-trust')
[[ -z "${url_token}" ]] && do_show_error "Não foi possível localizar o token A3, verifique se existe um token que não seja o 'p11-kit-trust' usando o comando: p11tool --list-token-urls"

# Localiza os detalhes dos certificados do token
opcoes=()
urls_certificado_usuario=()

while read -r linha; do
    # Verifica se a linha é URL de usuário
    tmp=$(echo "${linha}" | grep -oP 'URL:.*' | cut -c6- | grep -oP 'id=[^;]+')
    if [[ -n "${tmp}" ]]; then
        url="pkcs11:${tmp}"
        label=""
        expires=""
    fi

    # Verifica se a linha é o titulo
    tmp=$(echo "${linha}" | grep -oP ':\s[^:]+:[0-9]{11}')
    [[ -n "${tmp}" ]] && label="${tmp#* }"

    # Verifica se a linha é a data de validade
    tmp=$(echo "${linha}" | grep -oP 'Expir.+:.*')
    [[ -n "${tmp}" ]] && expires="${tmp#* }"

    # Configura as opções do whiptail
    id=$(echo "${linha}" | grep -oP 'ID:.*')

    if [ -n "${id}" ] && [ -n "${label}" ]; then
        # Ordena os valores de forma descendente
        opcoes=("${id}" "Expira:${expires}" "OFF" "${opcoes[@]}")
        urls_certificado_usuario+=("${id}${url}")
        label=""
    fi
done < <(p11tool --list-all-certs "${url_token}")

##############
# Solicita o ID do certificado do usuário
##############

# primeira opção selecionada como padrão
opcoes[2]="ON"
id_cert="$(whiptail --backtitle "Qual a certificado a ser utilizado" --title "Seleção do certificado" --ok-button="Continuar" --cancel-button="Sair" --radiolist "Selecione o certificado que deve ser usado pela VPN" 20 80 "${#opcoes[@]}" "${opcoes[@]}" 3>&1 1>&2 2>&3)"
do_check_selection "${id_cert}"

# Localiza a URL do token do usuário baseado no ID selecionado
url_cert=""
for i in "${urls_certificado_usuario[@]}"; do
    [[ "$i" == *"$id_cert"* ]] && url_cert=$(echo "${i}" | grep -oP 'pkcs11.*')
done
[[ -z "${url_cert}" ]] && do_show_error "Não foi possível localizar a URL do certificado"

##############
# Gera o cafile com a cadeia de certificados
##############

# Certificados da CA
do_download_cadeia_certificados

# Certificado do servidor
cert_dtp_srv_file="${DIR_NAME_CERTIFICADOS:?Variável DIR_NAME_CERTIFICADOS vazia}/servidor-vpn-dtp.crt"
echo " - Exportando certificados do servidor da VPN: ${SERVER_VPN} para o arquivo ${cert_dtp_srv_file}"
keytool -J"-Duser.language=en" -printcert -sslserver "${SERVER_VPN}:443" -rfc >"${cert_dtp_srv_file}"
grep -qoP 'BEGIN CERTIFICATE' "${cert_dtp_srv_file}" || do_show_error "O arquivo de certificado parece estar corrompido ou incompleto: ${cert_dtp_srv_file}"

echo " - Concatenando certificados para o arquivo ${PATH_CERTIFICADOS_PEM}"
cat "${DIR_NAME_CERTIFICADOS}"/*.crt > "${PATH_CERTIFICADOS_PEM}"
echo " - Cadeia contendo $(grep -o -i 'BEGIN CERTIFICATE' "${PATH_CERTIFICADOS_PEM}" | wc -l) certificados"

##############
# Cria o script de inicialização da VPN
##############
echo ""
echo "Configurando o script de inicialização da VPN ${PATH_VPN_SH}"
echo " - Criando arquivo ${PATH_VPN_SH}"
sudo rm "${PATH_VPN_SH}" 2>/dev/null
tee "${PATH_VPN_SH}" >/dev/null <<BLOCK
#!/bin/sh
sudo openconnect ${gateway} --protocol=gp ${SERVER_VPN} --cafile ${PATH_CERTIFICADOS_PEM} -u ${login_ldap}@dataprev.gov.br -c '${url_cert}'
BLOCK

# Marca o scitpt como inicializável
chmod +x "${PATH_VPN_SH}"

# Cria o arquivo de sudoers para permitir a execução sem 'sudo'
path_sudoers="/etc/sudoers.d/vpn"
echo " - Criando o arquivo de sudoers ${path_sudoers}"
sudo rm "${path_sudoers}" 2>/dev/null
# Nota: O arquivo de sudoers permite rodar o script sem permissão de root
sudo tee "${path_sudoers}" >/dev/null <<BLOCK
ALL    ALL = (root) NOPASSWD: ${PATH_VPN_SH}
BLOCK

# Cria o alias vpn no .bashrc
echo " - Criando o alias vpn no ${HOME}/.bashrc"
do_add_line_to_file "${HOME}/.bashrc" "alias vpn=" "alias vpn='sudo ${PATH_VPN_SH}'"
alias vpn='sudo ${PATH_VPN_SH}'

whiptail --title "Configuração finalizada" --msgbox "Para executar a VPN é necessário abrir uma nova janela do shell e digitar 'vpn'\nLembre-se de manter a janela aberta durante o uso da VPN.\nPara desconectar, pressione CTRL-C ou feche a janela" 15 78
