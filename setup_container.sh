#!/bin/bash
echo "${GREEN} Creating and configuring directories"
my_username=ubuntu
home_path=/home/$my_username
GREEN="\e[0;36m"
RESET="\e[0m"
ZSH_CUSTOM=$home_path/.oh-my-zsh/custom
sudo -u $my_username echo $ZSH_CUSTOM
sudo chown -R $my_username $home_path
sudo mkdir -p "$home_path/.config"
sudo chown -R $my_username "$home_path/.config"

cd $home_path

# Add fastfetch ppa
echo -e "${GREEN} Installing fastfetch ${RESET}"
wget "https://github.com/fastfetch-cli/fastfetch/releases/download/2.57.1/fastfetch-linux-amd64.deb"
apt install ./fastfetch-linux-amd64.deb

# echo "${GREEN} Setting github ssh login with Yubikey"
# ssh-keygen -t ed25519-sk -O resident -O verify-required -C "spam@davidthegardens.com"

# Install packages
echo -e "${GREEN} Installing updating apt and installing packages"${RESET}
apt update && apt upgrade -y
apt install -y wl-clipboard zip zoxide tmux fastfetch curl libssl-dev build-essential libclang-dev zsh bat entr python3 nodejs npm ripgrep fzf openssh-server python3.12-venv
snap install nvim --classic

# Install TPM for tmux
echo -e "${GREEN} Installing tpm for tmux"${RESET}
git clone https://github.com/tmux-plugins/tpm $home_path/.tmux/plugins/tpm
sudo chmod 777 $home_path/.tmux/plugins

# Install rust
echo -e "${GREEN} Installing rust"${RESET}
curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y

# Start ssh server on boot
echo -e "${GREEN} Configuring and starting ssh"${RESET}
sudo systemctl start ssh && sudo systemctl enable ssh

# Install oh-my-zsh
echo -e "${GREEN} Installing oh my zsh"${RESET}
sudo -u $my_username sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins
echo -e "${GREEN} Installing oh my zsh plugins"${RESET}
sudo -u $my_username git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
sudo -u $my_username git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
sudo -u $my_username git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git $ZSH_CUSTOM/plugins/zsh-autocomplete

# Add zsh customization
echo -e "${GREEN} Configuring .zshrc"${RESET}
cat <<EOF >>$home_path/.zshrc
alias cat="batcat"
alias cd="z"
alias ce="python3 -m venv venv"
alias ace="ce && source venv/bin/activate"
clear
fastfetch
alias vi="nvim"
export EDITOR="nvim"
alias lighten="sed -i s'/"tokyonight-night"/"tokyonight-light"/' $home_path/.config/nvim/lua/plugins/astroui.lua"
alias darken="sed -i s'/"tokyonight-light"/"tokyonight-night"/' $home_path/.config/nvim/lua/plugins/astroui.lua"
alias gcp="git add . && git commit -m 'routine commit' && git push"
EOF

# Customize tmux
echo -e "${GREEN} Customizing tmux"
cat <<EOF >"$home_path/.tmux.conf"
# Set prefix to C-Space
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# Reduce escape-time to prevent lag in terminal apps
set -s escape-time 0

# Set the default shell to be a login shell
set-option -g default-command "zsh"

# Force tmux to get the DISPLAY variable from the SSH session
set-option -g update-environment "DISPLAY"

# Terminal color support
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Enable mouse support
set -g mouse on

# Set vi-mode
set-window-option -g mode-keys vi

# Start windows and panes at 1, not 0
set -g base-index 1
set-window-option -g pane-base-index 1
set-option -g renumber-windows on
set -g status-right '#{prefix_highlight}'
# List of plugins
set -g @plugin 'tmux-plugins/tmux-prefix-highlight'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'christoomey/vim-tmux-navigator'
# set -g @plugin 'dreamsofcode-io/catppuccin-tmux'
set -g @plugin 'tmux-plugins/tmux-yank' # This will now handle clipboard
set -g @catppuccin_window_status_style "rounded"
# Catppuccin settings
# set -g @catppuccin_flavour 'mocha'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
set -g @plugin 'wfxr/tmux-power'
# You can set it to a true color in '#RRGGBB' format
set -g @tmux_power_theme '#7DCFFF' # dark slate blue
set-option -g default-shell /usr/bin/zsh

set -g allow-passthrough
set-option -sg set-clipboard on

bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'wl-copy'

# Change Enter to use system clipboard as well
unbind -T copy-mode-vi Enter
bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel 'wl-copy'

# Vi-like paste
bind P paste-buffer

# Or you can set it to 'colorX' which honors your terminal colorscheme

# The following colors are used as gradient colors
set -g @tmux_power_g0 "#1A1B26"
set -g @tmux_power_g1 "#414868"
set -g @tmux_power_g2 "#414868"
set -g @tmux_power_g3 "#414868"
set -g @tmux_power_g4 "#414868"
run '~/.tmux/plugins/tpm/tpm'
EOF

# Configure zoxide
echo -e "${GREEN} Configuring zoxide"${RESET}
echo 'eval "$(zoxide init zsh)"' >>$home_path/.zshrc
. "$HOME/.cargo/env"

# Install Treesitter for nvim
echo -e "${GREEN} Installing treesitty for nvim"${RESET}
cargo install --locked tree-sitter-cli

# Install disk analyzer
echo -e "${GREEN} Installing process analyzers for astrovim"${RESET}
curl -L https://github.com/dundee/gdu/releases/latest/download/gdu_linux_amd64.tgz | tar xz
chmod +x gdu_linux_amd64
mv gdu_linux_amd64 /usr/bin/gdu

# Install process analyzer
curl -LO https://github.com/ClementTsang/bottom/releases/download/0.11.4/bottom_0.11.4-1_amd64.deb
sudo dpkg -i bottom_0.11.4-1_amd64.deb

# Install NVM
echo -e "${GREEN} Installing nvm"${RESET}
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

# Install lazygit
echo -e "${GREEN} Installing lazygit"${RESET}
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit -D -t /usr/local/bin/

# Delete any existing nvim config
echo -e "${GREEN} Deleting old nvim configs"${RESET}
rm -rf $home_path/.config/nvim

# Install astrovim config
echo -e "${GREEN} Install astrovim"${RESET}
git clone --depth 1 https://github.com/AstroNvim/template $home_path/.config/nvim
rm -rf $home_path/.config/nvim/.git

# Configure git
echo -e "${GREEN} Configuring git"${RESET}
sudo -u ubuntu git config --global user.name "davidthegardens"
sudo -u ubuntu git config --global user.email "github.matador258@passmail.net"

# Change zsh preferences
echo -e "${GREEN} Changing zsh preferences"${RESET}
sed -i s'/plugins=(git)/plugins=(git ssh ubuntu vi-mode zsh-syntax-highlighting zsh-autosuggestions zsh-autocomplete)/' $home_path/.zshrc
sed -i s'/"robbyrussell"/bira/' $home_path/.zshrc

# Change astrovim theme to tokyo night
echo -e "${GREEN} Setting neovim theme"${RESET}
sed -i '1d' $home_path/.config/nvim/lua/community.lua
sed -i '1d' $home_path/.config/nvim/lua/plugins/astroui.lua

sed -i s'/{ import = "astrocommunity.pack.lua" },/{ import = "astrocommunity.pack.lua" },\
  {import = "astrocommunity.colorscheme.tokyonight-nvim"},\
  { import = "astrocommunity.recipes.cache-colorscheme" },/' $home_path/.config/nvim/lua/community.lua
sed -i s'/"astrodark"/"tokyonight-night", -- use tokyonight-light for a lightmode/' $home_path/.config/nvim/lua/plugins/astroui.lua
sed -i '1d' $home_path/.bashrc
exit
