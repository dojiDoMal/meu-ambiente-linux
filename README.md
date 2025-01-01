# Configuração do Ambiente

Este documento fornece instruções para configurar o ambiente com os temas, pacotes e ferramentas necessários.

---

## Passo a Passo

### 1. Configurar Aparência
1. **Baixar o tema de ícones Colloid**  
   - Faça o download do arquivo `.tar.xz` do tema [Colloid icon theme](https://github.com/vinceliuice/Colloid-icon-theme).
   - Extraia o conteúdo para a pasta:  
     `/home/anderson/.icons`
   - Configure os ícones:
     - Vá para: **Aparência > Ícones** > Selecione **Colloid-dark**.
   
2. **Configurar o estilo**  
   - Vá para: **Aparência > Estilo** > Selecione **Greybird-dark**.

3. **Configurar a fonte**  
   - Vá para: **Aparência > Fontes > Fonte monoespaçada padrão**.
   - Selecione: **JetBrainsMono Nerd Font Regular**.  
     Caso não tenha a fonte instalada, [baixe-a aqui](https://www.nerdfonts.com/) e extraia o conteúdo para a pasta `/home/anderson/.fonts`.

4. **Configurar o gerenciador de janelas**  
   - Extraia o arquivo Mojave-Dark.tar.gz para o diretório `/usr/share/themes/`
   - Vá para: **Gerenciador de Janelas > Estilo**.  
   - Selecione o tema: **Mojave-Dark**.

5. **Personalizar o Firefox**  
   - Clique com o botão direito na barra do Firefox.
   - Vá para: **Personalizar o Firefox**.
   - No canto inferior esquerdo, marque a opção **Barra de título**.

---

### 2. Instalar o OpenJDK 21
Execute o comando abaixo para instalar o OpenJDK 21:  
```bash
sudo apt install openjdk-21-jdk 
```

### 3. Instalar Pacotes Necessários
Execute o comando abaixo para instalar os pacotes requeridos:  
```bash
sudo apt install whiptail keytool curl unrar tar wget nc openconnect p11tool 
```

### 4. Instalar o Chromium
Para acessar o PWA do Microsoft Teams e WhatsApp Web, instale o Chromium:  
```bash
sudo apt install chromium-browser 
```
