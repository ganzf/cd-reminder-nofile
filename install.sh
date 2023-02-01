#!/bin/bash

echo -e "Copy directory to $HOME/.oh-my-zsh/custom/plugins"
rm -rf $HOME/.oh-my-zsh/custom/plugins/cd-reminder
cp -r src $HOME/.oh-my-zsh/custom/plugins/cd-reminder

echo -e "Now add cd-reminder to plugins in $HOME/.zshrc !"