###########################################################################################################
# Script contendo funções genéricas que são compartilhadas pelos demais scripts
# Para utilizar, declare no inicio do script:
# source $(dirname "$0")/functions.sh
###########################################################################################################
DIR_LINKS=/usr/bin
DIR_NAME_VPN="${HOME}/dtpvpn"
DIR_NAME_CERTIFICADOS="${DIR_NAME_VPN}/certificados"

# Exibe uma mensagem de erro e interrompe o fluxo
do_show_error() {
    #Exibe a mensagem de erro, se passada como parâmetro
    [[ -n "${1}" ]] && echo -e "\e[31;1m${1}\e[m\n"
    exit 1
}

# Exibe uma mensagem de aviso
do_show_warn() {
    #Exibe a mensagem de aviso, se passada como parâmetro
    [[ -n "${1}" ]] && echo -e "\e[33;1m${1}\e[m"
}

# Verifica se o usuário cancelou a operação
do_check_selection() {
    if [[ -z "${1}" ]]; then
        echo "Operação cancelada pelo usuário."
        exit 1
    fi
}

# Verifica a presença de um aplicativo
do_check_app() {
    echo -n "Verificando aplicativo ${1}"
    tmp="$(
        command -v "${1}" >/dev/null
        echo $?
    )"
    do_print_task_result "${tmp}"
    if [ "0" != "${tmp}" ]; then
        echo "Atenção: É necessário instalar o aplicativo ${1} para continuar"
        exit 1
    fi
}

# Verifica a presença de uma lista de aplicativos
do_check_apps() {
    local arr=("$@")
    for i in "${arr[@]}"; do
        do_check_app "$i"
    done
}

# Exibe o status no final da linha
do_print_task_result() {
    local col=100
    local eol="\033[${col}D\033[${col}C"

    if [ "0" == "${1}" ] || [ -z "${1}" ]; then
        echo -en "${eol} [\e[32;1mOK\e[m]\n"
    else
        echo -en "${eol} [\e[31;1mErro\e[m]\n"
    fi
}

# Exibe o status no final da linha
do_print_task_result_with_text() {
    local col=100
    local eol="\033[${col}D\033[${col}C"

    if [ "0" == "${1}" ] || [ -z "${1}" ]; then
        echo -en "${eol} [\e[31;1mErro\e[m]\n"
    else
        echo -en "${eol} [\e[32;1mOK\e[m]\n"
    fi
}

# remove um arquivo
do_remove_file() {
    local file_name="${1}"
    if [[ -f "${file_name}" ]]; then
        echo -n "Removendo arquivo ${file_name}"
        sudo rm "${file_name:?Variável arquivo vazia}" 2>/dev/null
        do_print_task_result "$?"
    fi
}

# Adiciona uma linha em um arquivo, como usuário comum
do_add_line_to_file() {
    local file_name="${1}"
    local line_prefix="${2}"
    local line="${3}"

    # Remove a linha existente
    [[ -n "${line_prefix}" ]] && sudo grep -Fq "${line_prefix}" "${file_name}" && sudo sed -i "/^${line_prefix}/d" "${file_name}"
    # Adiciona a nova linha
    echo "${line}" | sudo tee -a "${file_name}" >/dev/null
}

#A diciona uma linha em um arquivo, como usuário comum ou root
do_add_line_to_file_sudo() {
    local file_name="${1}"
    local line_prefix="${2}"
    local line="${3}"
    local as_root="${4}"
    local remove_line="${5}"

    if [[ -z "${as_root}" ]]; then
        #Remove a linha existente
        [[ -n "${line_prefix}" ]] && grep -Fq "${line_prefix}" "${file_name}" && sed -i "/^${line_prefix}/d" "${file_name}"
        #Adiciona a nova linha
        [[ -z "${remove_line}" ]] && echo "${line}" >>"${file_name}"
    else
        #Remove a linha existente
        [[ -n "${line_prefix}" ]] && sudo grep -Fq "${line_prefix}" "${file_name}" && sudo sed -i "/^${line_prefix}/d" "${file_name}"
        #Adiciona a nova linha
        [[ -z "${remove_line}" ]] && sudo echo "${line}" | sudo tee -a "${file_name}" >/dev/null
    fi
}

# Remove a linha de um arquivo
do_remove_line_from_file() {
    local file_name="${1}"
    local line_prefix="${2}"

    #Remove a linha existente
    if sudo grep -Fq "${line_prefix}" "${file_name}"; then
        echo -n "Removendo do arquivo ${file_name} o texto [${line_prefix}]"
        sudo sed -i "/${line_prefix}/d" "${file_name}"
        do_print_task_result "$?"
    fi
}

# Verifica se o usuário tem acesso de root
do_ensure_sudo() {
    sudo whoami >/dev/null 2>/dev/null || do_show_error "Erro: É necessário acesso de super usuário para edição dos arquivos de configuração"
}

#Verifica se a distro é baseada em Debian
do_ensure_debian() {
    command -v dpkg-reconfigure >/dev/null || do_show_error "Erro: Script compatível apenas com o formato de certificado de distribuições baseadas no Debian"
}

# Cria o link para o aplicativo
do_create_link() {
    local file_path="${1}"
    local target
    target="${DIR_LINKS}/$(basename "${file_path}")"
    echo -n " ${target} -> ${file_path}"
    sudo rm -f "${target:?Variável target vazia}" 2>/dev/null
    sudo ln -s "${file_path:?Variável file_path vazia}" "${target:?Variável target vazia}"
    do_print_task_result "$?"
}

# Efetua download de um arquivo temporário
do_download_temp_file() {
    local url="${1}"
    local temp_file="${2}"
    # remove o arquivo temporário
    sudo rm -f "${temp_file}" 2>/dev/null

    # Efetua o download do certificado
    echo -n "Efetuando download do arquivo ${temp_file} da URL: ${url}"
    #curl --insecure "${url}" --output "${temp_file}" 2>/dev/null

    if [[ "${url}" =~ docs.google.com ]]; then
        wget --no-check-certificate -O "${temp_file}" "${url}" -r -A 'uc*' -e robots=off -nd
    else
        wget --no-check-certificate -O "${temp_file}" "${url}"
    fi

    [[ ! -f "${temp_file}" ]] && do_show_error "Erro: Falha ao efetuar o download do arquivo ${temp_file} de: ${url}"
    do_print_task_result "0"
}

# Exibe uma caixa de texto com título em mensagem solicitando uma informação
do_ask_question() {
    local title="${1}"
    local default_value="${2}"
    local question="${3}"
    ANSWER=$(whiptail --backtitle "Configuração da VPN" --inputbox "${title}" 8 78 "${default_value}" --title "${question}" 3>&1 1>&2 2>&3)
    do_check_selection "${ANSWER}"
}

# Efetua o download dos certificados do site do ICP Brasil
do_download_cadeia_certificados() {
    opcoes=()
    opcoes+=("SOLUTI" "AC Soluti V5" "ON")
    opcoes+=("CERTISIGN" "AC CertiSign / RFB V5" "OFF")

    emissor="$(whiptail --backtitle "Qual a CA emissora do certificado?" --title "Seleção do emissor" --ok-button="Continuar" --cancel-button="Sair" --radiolist "Selecione o emissor do certificado" 20 60 "${#opcoes[@]}" "${opcoes[@]}" 3>&1 1>&2 2>&3)"
    do_check_selection "${emissor}"

    cadeia_certificados=("https://acraiz.icpbrasil.gov.br/credenciadas/RAIZ/ICP-Brasilv5.crt")
    cadeia_certificados+=("https://acraiz.icpbrasil.gov.br/credenciadas/RAIZ/ICP-Brasilv10.crt")
    cadeia_certificados+=("https://acraiz.icpbrasil.gov.br/credenciadas/CERTISIGN/v10/p/AC-CERTISIGN-ICP-BRASIL-SSL-G2.crt")

    if [[ "${emissor}" == "SOLUTI" ]]; then
        cadeia_certificados+=("https://acraiz.icpbrasil.gov.br/credenciadas/SOLUTI/v5/p/AC_Soluti_v5.crt")
        cadeia_certificados+=("https://acraiz.icpbrasil.gov.br/credenciadas/SOLUTI/v5/AC_SOLUTI_Multipla_v5.crt")
        cadeia_certificados+=("https://acraiz.icpbrasil.gov.br/credenciadas/SOLUTI/v5/p/AC-SOLUTI-v5-G2.crt")
        cadeia_certificados+=("https://acraiz.icpbrasil.gov.br/credenciadas/SOLUTI/v5/AC_SOLUTI_Multipla_v5_G2.crt")
    else
        cadeia_certificados+=("https://acraiz.icpbrasil.gov.br/credenciadas/RFB/v5/p/AC_Secretaria_da_Receita_Federal_do_Brasil_v4.crt")
        cadeia_certificados+=("https://acraiz.icpbrasil.gov.br/credenciadas/RFB/v5/AC_Certisign_RFB_G5.crt")
    fi

    # Cria o diretório dos certificados
    [[ -d "%{DIR_NAME_CERTIFICADOS}" ]] || mkdir -p "${DIR_NAME_CERTIFICADOS}"

    echo " - Efetuando download da cadeia de certificados"
    size=${#cadeia_certificados[@]}
    local arquivo_crt
    for ((x = 0; x < size; x++)); do
        arquivo_crt="${DIR_NAME_CERTIFICADOS}/$((x + 1)).crt"
        do_download_temp_file "${cadeia_certificados[x]}" "${arquivo_crt}"
        grep -qoP 'BEGIN CERTIFICATE' "${arquivo_crt}" || do_show_error "O arquivo de certificado parece estar corrompido ou incompleto: ${arquivo_crt}"
    done
}

do_instala_certificados_firefox() {
    echo " - Importando cadeia de certificados do Firefox"
    policies_dir="/etc/firefox/policies"
    [[ -d "${policies_dir}" ]] || sudo mkdir -p "${policies_dir}"

    policies_json="${policies_dir}/policies.json"
    [[ -f "${policies_json}" ]] && sudo rm "${policies_json}"

    # Fecha o firefox
    echo " - Fechando o firefox"
    pkill firefox

    lista_arquivos=$(find "${DIR_NAME_CERTIFICADOS}" -type f -printf "\"%p\"," | rev | cut -c2- | rev)

    # Cria o arquivo de configuração do Firefox
    echo " - Criando o arquivo de configuração do Firefox: ${policies_json}"
    sudo tee "${policies_json}" >/dev/null <<BLOCK
{
    "policies": {
        "SecurityDevices": {
            "eToken": "/usr/lib/libeToken.so"
        },
        "Certificates": {
            "ImportEnterpriseRoots": true,
            "Install": [${lista_arquivos}]
        }
    }
}
BLOCK

    # Abre o firefox na página de configuração
    echo " - Abrindo o firefox na página de configurações "
    firefox --preferences &

    echo ""
    echo "-------------------------------------------------------------------------------"
    echo "Driver instalado, será necessário verificar as configurações do Firefox:"
    echo ""
    echo "1) Abrir a página de privacidade, em configurações"
    echo "2) Selecionar a opção 'View Certificates' e a aba 'Authorities'"
    echo "3) Verifique se a cadeia do ICP Brasil está cadastrada, caso contrário será necessário configurar manualmente:"
    echo "  - Clicar em 'Import' e importar os arquivos *.crt do diretório: ${DIR_NAME_CERTIFICADOS}, 1 por vez"
    echo "  - Durante a importação do certificado, conceder permissão de assinatura"
    echo "4) Voltar para a página de privacidade e clicar no botão 'Security Devices...'"
    echo "5) Verificar se o módulo eToken está cadastrado, caso contrário será necessário configurar manualmente:"
    echo "  - Clicar no botão 'Load' para carregar o driver do eToken"
    echo "  - Informar no Module name 'eToken' e no 'Module Filename', /usr/lib/libeToken.so"
    echo ""
    echo "Após esses passos, o Firefox, Chrome e Libre office estarão prontos para utilizar o token"
    echo ""
    echo "Nota: caso tenha configurado manualmente, será necessário reiniciar o Firefox antes de verificar o funcionamento"
    echo ""
    echo "Verificar o funcionamento do certificado nos browsers logando na página do e-cac: https://cav.receita.fazenda.gov.br/"
    echo "Clicar na opção de login usando certificado, informar a senha do token e confirmar o usuário."
    echo ""

}
