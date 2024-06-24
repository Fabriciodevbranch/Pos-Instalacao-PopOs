#!/bin/bash

# Redirect all output to a log file
exec > >(tee -a /home/$USER/Documentos/Log_PostInstall/Log.txt)
exec 2>&1

# Antes de executar o script, avisa ao usuário sobre as modificações que serão feitas
read -p "Este script irá instalar pacotes e modificar o sistema. Deseja continuar? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Execução interrompida."
    exit 0
fi

# Instala o pacote pv
sudo apt install -y pv 

# Define a posição do Docker à direita com um tamanho de 36px
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position RIGHT
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 36

# Solicita a URL da imagem ao usuário
read -p "Digite a URL da imagem (pressione enter para pular): " image_url

# Verifica se a URL da imagem foi fornecida
if [ -n "$image_url" ]; then
    # Obtém e define uma imagem da URL fornecida como papel de parede
    wget -O /home/$USER/Imagens/wallpaper.jpg "$image_url" | pv -lep -s "$(wget --spider "$image_url" 2>&1 | grep 'Length:' | awk '{print $2}')"
    if [[ "$image_url" == *.png ]]; then
        mv /home/$USER/Imagens/wallpaper.jpg /home/$USER/Imagens/wallpaper.png
    fi
    gsettings set org.gnome.desktop.background picture-uri "file:///home/$USER/Imagens/wallpaper.jpg"
fi

# Configura as credenciais do Git
read -p "Digite seu nome: " name
read -p "Digite seu email: " email

if [ -n "$name" ] && [ -n "$email" ]; then
    git config --global user.name "$name"
    git config --global user.email "$email"
fi

# Atualiza e faz upgrade do apt
sudo apt update | pv -lep
sudo apt upgrade -y | pv -lep
sudo apt dist-upgrade -y | pv -lep

# Instala pacotes usando apt
sudo apt install -y vlc sublime-text python | pv -lep

# Instala pacotes usando snap
sudo snap install telegram-desktop post htop | pv -lep
sudo snap install rclone --classic | pv -lep
sudo snap install code --classic | pv -lep

# Instala o node, npm e angular
sudo apt install -y nodejs npm | pv -lep
sudo npm install -g @angular/cli | pv -lep

# Instala o Docker
sudo apt install -y docker.io | pv -lep
# Adiciona o usuário atual ao grupo docker
sudo usermod -aG docker $USER
# Pergunta ao usuário se deseja instalar as imagens do Postgres e Oracle
read -p "Deseja instalar a imagem do Postgres? (y/n): " install_postgres_image
read -p "Deseja instalar a imagem do Oracle? (y/n): " install_oracle_image

# Array para armazenar as imagens a serem instaladas
images=()

# Verifica as respostas do usuário e adiciona as imagens ao array
if [ "$install_postgres_image" == "y" ]; then
    images+=("postgres")
fi

if [ "$install_oracle_image" == "y" ]; then
    images+=("oracleinanutshell/oracle-xe-11g")
fi

# Instala as imagens selecionadas
failed_images=()
for image in "${images[@]}"; do
    sudo docker pull "$image" | pv -lep
    if [ $? -ne 0 ]; then
        failed_images+=("$image")
    fi
done

# Configura as imagens para persistir os dados em um volume
if [ "$install_postgres_image" == "y" ]; then
    sudo docker run --name postgres -e POSTGRES_PASSWORD=postgres -d -v /home/$USER/docker/volumes/postgres:/var/lib/postgresql/data postgres | pv -lep
fi

if [ "$install_oracle_image" == "y" ]; then
    sudo docker run --name oracle -d -p 49161:1521 -v /home/$USER/docker/volumes/oracle:/u01/app/oracle oracleinanutshell/oracle-xe-11g | pv -lep
fi

# Instala o Google Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb | pv -lep
sudo dpkg -i google-chrome-stable_current_amd64.deb | pv -lep
sudo apt --fix-broken install -y | pv -lep
rm google-chrome-stable_current_amd64.deb

# Configura o Google Chrome como navegador padrão
xdg-settings set default-web-browser google-chrome.desktop

# Instala e configura o Flatpak e Flathub
sudo apt install -y flatpak | pv -lep
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo | pv -lep

# Instala o Microsoft Teams do Flathub
flatpak install flathub com.microsoft.Teams | pv -lep

# Pergunta ao usuário se deseja instalar as extensões
read -p "Deseja instalar as extensões do Oracle? (y/n): " install_oracle
read -p "Deseja instalar as extensões do Postgres? (y/n): " install_postgres
read -p "Deseja instalar as extensões do Docker? (y/n): " install_docker
read -p "Deseja instalar a extensão do GitHub Copilot? (y/n): " install_copilot
read -p "Deseja instalar a extensão do NuGet Package Manager? (y/n): " install_nuget

# Array para armazenar as extensões a serem instaladas
extensions=()

# Verifica as respostas do usuário e adiciona as extensões ao array
if [ "$install_oracle" == "y" ]; then
    extensions+=("oracle.oracledevtools")
fi

if [ "$install_postgres" == "y" ]; then
    extensions+=("vscode-postgres")
fi

if [ "$install_docker" == "y" ]; then
    extensions+=("ms-azuretools.vscode-docker")
fi

if [ "$install_copilot" == "y" ]; then
    extensions+=("github.copilot")
fi

if [ "$install_nuget" == "y" ]; then
    extensions+=("ms-dotnettools.nuget-package-manager")
fi

# Instala as extensões selecionadas
failed_extensions=()
for extension in "${extensions[@]}"; do
    code --install-extension "$extension"
    if [ $? -ne 0 ]; then
        failed_extensions+=("$extension")
    fi
done

# Instala o tema Dracula no vscode
code --install-extension dracula-theme.theme-dracula

# Instala o tema Material Icon Theme no vscode
code --install-extension pkief.material-icon-theme


# Cria um diretorio na pasta de documentos do usuario chamaod projetos
mkdir /home/$USER/Documentos/projetos

# Adiciona um alias para o comando top apontando para o htop no .bashrc
echo "alias top='htop'" >> ~/.bashrc

# Função para navegar para uma pasta acima na árvore de diretórios, recebendo o número de níveis como argumento no bashrc
echo "function up() {
    cd \$(printf '%0.s../' {1..\$1})
}" >> ~/.bashrc

# Função para criar um novo diretório e navegar até ele, recebendo o nome do diretório como argumento no bashrc
echo "function mkcd() {
    mkdir -p \$1
    cd \$1
}" >> ~/.bashrc

# Cria um Perfil no console e define-o como padrão, configurando para usar transparência e definindo-o como 25%
echo "export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> ~/.bashrc

#Cria um diretorio na  pasta de documentos do usuario chamado cofre e dentro dele cria um arquivo chamado senhas.txt, o diretorio e o arquivo são ocultos e o arquivo é protegido com senha
mkdir /home/$USER/Documentos/.cofre
touch /home/$USER/Documentos/.cofre/.senhas.txt
echo "Digite a senha para proteger o arquivo de senhas"
read -s senha
echo $senha | gpg --batch --yes --passphrase-fd 0 -c /home/$USER/Documentos/.cofre/.senhas.txt

# Solicita se deseja configurar o google drive e solicita o email e a senha e cria um diretorio na pasta de documentos do usuario chamado google_drive sincronizada com o gdrive

if [ "$install_google_drive" == "y" ]; then
    echo "Digite o email do Google Drive"
    read email
    echo "Digite a senha do Google Drive"
    read -s senha
    read -p "Deseja configurar o Google Drive? (y/n): " install_google_drive
    read -p "cliente_id: " client_id
    read -p "client_secret: " client_secret
    mkdir /home/$USER/Documentos/google_drive
    rclone config create google_drive drive scope drive.file client_id $client_id client_secret $client_secret
    rclone config file
    rclone config password
    rclone configImagem password $email $senha
    rclone mount google_drive: /home/$USER/Documentos/google_drive
fi

# Verifica se houve falhas durante a execução do script
if [ ${#failed_images[@]} -eq 0 ] && [ ${#failed_extensions[@]} -eq 0 ]; then
    echo "Checklist de execução:"
    echo "----------------------"
    echo "✔️ Modificações no sistema"
    echo "✔️ Imagem de papel de parede definida"
    echo "✔️ Credenciais do Git configuradas"
    echo "✔️ Atualização e upgrade do apt"
    echo "✔️ Pacotes instalados usando apt"
    echo "✔️ Pacotes instalados usando snap"
    echo "✔️ Node, npm e Angular instalados"
    echo "✔️ Docker instalado"
    echo "✔️ Imagens do Postgres e Oracle instaladas"
    echo "✔️ Google Chrome instalado"
    echo "✔️ Flatpak e Flathub instalados"
    echo "✔️ Microsoft Teams instalado"
    echo "✔️ Extensões do Oracle, Postgres, Docker, GitHub Copilot e NuGet Package Manager instaladas"
    echo "✔️ Tema Dracula e Material Icon Theme instalados no VSCode"
    echo "✔️ Diretório 'projetos' criado"
    echo "✔️ Alias 'top' adicionado para o comando 'htop'"
    echo "✔️ Funções 'up' e 'mkcd' adicionadas ao bashrc"
    echo "✔️ Perfil do console configurado"
    echo "✔️ Diretório 'cofre' e arquivo 'senhas.txt' criados e protegidos com senha"
    echo "✔️ Diretório 'google_drive' criado e configurado com o Google Drive"
else
    echo "Checklist de execução:"
    echo "----------------------"
    echo "❌ Modificações no sistema"
    echo "❌ Imagem de papel de parede definida"
    echo "❌ Credenciais do Git configuradas"
    echo "❌ Atualização e upgrade do apt"
    echo "❌ Pacotes instalados usando apt"
    echo "❌ Pacotes instalados usando snap"
    echo "❌ Node, npm e Angular instalados"
    echo "❌ Docker instalado"
    echo "❌ Imagens do Postgres e Oracle instaladas"
    echo "❌ Google Chrome instalado"
    echo "❌ Flatpak e Flathub instalados"
    echo "❌ Microsoft Teams instalado"
    echo "❌ Extensões do Oracle, Postgres, Docker, GitHub Copilot e NuGet Package Manager instaladas"
    echo "❌ Tema Dracula e Material Icon Theme instalados no VSCode"
    echo "❌ Diretório 'projetos' criado"
    echo "❌ Alias 'top' adicionado para o comando 'htop'"
    echo "❌ Funções 'up' e 'mkcd' adicionadas ao bashrc"
    echo "❌ Perfil do console configurado"
    echo "❌ Diretório 'cofre' e arquivo 'senhas.txt' criados e protegidos com senha"
    echo "❌ Diretório 'google_drive' criado e configurado com o Google Drive"

    if [ ${#failed_images[@]} -ne 0 ]; then
        echo "Imagens que falharam:"
        for image in "${failed_images[@]}"; do
            echo "❌ $image"
        done
    fi

    if [ ${#failed_extensions[@]} -ne 0 ]; then
        echo "Extensões que falharam:"
        for extension in "${failed_extensions[@]}"; do
            echo "❌ $extension"
        done
    fi
fi