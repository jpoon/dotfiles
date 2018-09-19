#!/bin/sh

# Homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew install go nvm git bash-completion vim tmux kubectl

# Fonts
brew tap caskroom/fonts
brew cask install font-hack-nerd-font java

# YubiSwitch
brew tap homebrew/cask-drivers
brew cask install pallotron-yubiswitch

echo "Update Yubikey with:"
ioreg -p IOUSB -l -w 0 -x | grep Yubikey -A10 | grep idProduct
ioreg -p IOUSB -l -w 0 -x | grep Yubikey -A10 | grep idVendor

# Powerlevel
git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/themes/powerlevel9k

# Hard-links
ln .tmux.conf ~/.tmux.conf
ln .zshrc ~/.zshrc
ln .vimrc ~/.vimrc 
