#!/bin/bash
# Remove a alternância automática de fone instalada por fone_auto_instalar.sh
# e devolve a saída ao modo original da imagem (SPK_HP).

TELA=/dev/tty1
printf '\033c' > "$TELA" 2>/dev/null
printf '%s\n' "Removendo a troca automática de fone..." > "$TELA" 2>/dev/null

sudo systemctl disable --now fone-auto.service > /dev/null 2>&1
sudo rm -f /etc/systemd/system/fone-auto.service /usr/local/bin/fone_auto.sh
sudo systemctl daemon-reload > /dev/null 2>&1
amixer -q -c 0 cset name='Playback Path' SPK_HP > /dev/null 2>&1
sync

printf '%s\n' "Removido. A saída voltou ao modo SPK_HP." > "$TELA" 2>/dev/null
sleep 5
exit 0
