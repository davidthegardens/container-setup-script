#!/bin/bash
my_username=/home/ubuntu
ZSH_CUSTOM=$my_username/.oh-my-zsh/custom
echo $my_username
sudo -u ubuntu echo $ZSH_CUSTOM
sudo chown -R ubuntu /home/ubuntu
sudo chown ubuntu /home/ubuntu/.zshrc

# Add fastfetch ppa
add-apt-repository -y ppa:zhangsongcui3371/fastfetch

# Install packages
apt update && apt upgrade -y
apt install -y wl-clipboard zip zoxide tmux fastfetch curl libssl-dev build-essential zsh bat entr python3 nodejs npm ripgrep fzf openssh-server
snap install nvim --classic

# Install Git Credential Manager
wget https://github.com/git-ecosystem/git-credential-manager/releases/download/v2.6.1/gcm-linux_amd64.2.6.1.deb

# Install TPM for tmux
git clone https://github.com/tmux-plugins/tpm $my_username/.tmux/plugins/tpm
sudo chmod 777 $my_username/.tmux/plugins

# Install rust
curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y

# Start ssh server on boot
sudo systemctl start ssh && sudo systemctl enable ssh

# Install oh-my-zsh
# sudo -u ubuntu sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# wait
# Install zsh plugins
sudo -u ubuntu git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
sudo -u ubuntu git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
sudo -u ubuntu git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git $ZSH_CUSTOM/plugins/zsh-autocomplete

# Add zsh customization
cat <<EOF >>$my_username/.zshrc
export ZSH="/home/ubuntu/.oh-my-zsh"
ZSH_THEME=bira
plugins=(git ssh ubuntu vi-mode zsh-syntax-highlighting zsh-autosuggestions zsh-autocomplete)
source $ZSH/oh-my-zsh.sh
export NVM_DIR="$HOM/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion.sh"


alias cat="batcat"
alias cd="z"
alias ce="python3 -m venv venv"
alias ace="ce && source venv/bin/activate"
clear
fastfetch
alias vi="nvim"
export EDITOR="nvim"
alias lighten="sed -i s'/"tokyonight-night"/"tokyonight-light"/' $my_username/.config/nvim/lua/plugins/astroui.lua"
alias darken="sed -i s'/"tokyonight-light"/"tokyonight-night"/' $my_username/.config/nvim/lua/plugins/astroui.lua"
EOF

# Customize tmux
cat <<EOF >"$my_username/.tmux.conf"
# Set prefix to C-Space
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# Reduce escape-time to prevent lag in terminal apps
set -s escape-time 0

# Set the default shell to be a login shell
set-option -g default-command "/bin/bash -l"

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
echo 'eval "$(zoxide init zsh)"' >>$my_username/.zshrc
. "$HOME/.cargo/env"

# Install Treesitter for nvim
cargo install --locked tree-sitter-cli

# Install disk analyzer
curl -L https://github.com/dundee/gdu/releases/latest/download/gdu_linux_amd64.tgz | tar xz
chmod +x gdu_linux_amd64
mv gdu_linux_amd64 /usr/bin/gdu

# Install process analyzer
curl -LO https://github.com/ClementTsang/bottom/releases/download/0.11.4/bottom_0.11.4-1_amd64.deb
sudo dpkg -i bottom_0.11.4-1_amd64.deb

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

# Install lazygit
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit -D -t /usr/local/bin/

# Delete any existing nvim config
rm -rf $my_username/.config/nvim

# Install astrovim config
git clone --depth 1 https://github.com/AstroNvim/template $my_username/.config/nvim

# remove template's git connection to set up your own later
rm -rf $my_username/.config/nvim/.git

# Configure git
git config --global user.name "davidthegardens"
git config --global user.email "github.matador258@passmail.net"

# Change zsh preferences
sed -i s'/plugins=(git)/plugins=(git ssh ubuntu vi-mode zsh-syntax-highlighting zsh-autosuggestions zsh-autocomplete)/' $my_username/.zshrc
sed -i s'/"robbyrussell"/bira/' $my_username/.zshrc

# Change astrovim theme to tokyo night
sed -i '1d' $my_username/.config/nvim/lua/community.lua
sed -i '1d' $my_username/.config/nvim/lua/plugins/astroui.lua

sed -i s'/{ import = "astrocommunity.pack.lua" },/{ import = "astrocommunity.pack.lua" },\
  {import = "astrocommunity.colorscheme.tokyonight-nvim"},\
  { import = "astrocommunity.recipes.cache-colorscheme" },/' $my_username/.config/nvim/lua/community.lua
sed -i s'/"astrodark"/"tokyonight-night", -- use tokyonight-light for a lightmode/' $my_username/.config/nvim/lua/plugins/astroui.lua
sed -i '1d' $my_username/.bashrc
exit
