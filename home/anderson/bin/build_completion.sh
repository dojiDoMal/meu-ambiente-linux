#!/bin/bash

_build_completions() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Define a list of available projects for autocompletion
    local projects="meu-inss-service meu-inss-gateway meu-inss-mobile meu-inss-gestao-api inss-notificacoes-registro-api meu-inss-internet portal-spa central-servico-react meu-inss-gestao-spa inss-notificacoes-batch inss-notificacoes-api inss-notificacoes-config-api inss-notificacoes-commons"

    # Provide suggestions based on the current input
    COMPREPLY=( $(compgen -W "$projects" -- "$cur") )
    return 0
}

complete -F _build_completions start
complete -F _build_completions build

