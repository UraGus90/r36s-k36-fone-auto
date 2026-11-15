#!/bin/bash
# Diagnóstico da detecção de fone de ouvido (ArkOS K36).
# Não altera nenhuma configuração: só lê o estado do áudio e grava um relatório
# em /roms/tools/diag_fone_log.txt (pasta "tools" da partição EASYROMS).

LOG=/roms/tools/diag_fone_log.txt
TMP=/tmp/diag_fone
TELA=/dev/tty1

diz() { printf '%s\n' "$*" > "$TELA" 2>/dev/null; }

conta() {  # conta <segundos> <mensagem>
  local s
  for ((s = $1; s > 0; s--)); do
    printf '\r%s  [%2d s] ' "$2" "$s" > "$TELA" 2>/dev/null
    sleep 1
  done
  printf '\n' > "$TELA" 2>/dev/null
}

retrato() {  # estado que pode mudar com o fone
  echo
  echo "===== RETRATO: $1 ($(date '+%H:%M:%S')) ====="
  echo "--- Playback Path"
  amixer -c 0 cget name='Playback Path' 2>&1
  echo "--- extcon"
  for e in /sys/class/extcon/*; do
    [ -e "$e/state" ] && { echo "$e nome=$(cat "$e/name" 2>/dev/null)"; cat "$e/state"; }
  done
  echo "--- gpio (debugfs)"
  sudo cat /sys/kernel/debug/gpio 2>&1 | grep -iE 'gpiochip|hp|spk|det|con|head|amp'
  echo "--- controles de jack / fone / alto-falante"
  amixer -c 0 contents 2>&1 | grep -A3 -iE 'jack|headphone|headset|speaker'
  echo "--- chave SW_HEADPHONE_INSERT por dispositivo (0 = solta, 10 = acionada)"
  for d in /dev/input/event*; do
    sudo evtest --query "$d" EV_SW SW_HEADPHONE_INSERT > /dev/null 2>&1
    echo "$d: $?"
  done
}

rm -rf "$TMP"; mkdir -p "$TMP"
mountpoint -q /sys/kernel/debug || sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null

printf '\033c' > "$TELA" 2>/dev/null
diz "Diagnóstico do fone de ouvido"
diz "Deixe o fone DESCONECTADO para começar."
diz ""

{
  echo "##### DIAGNÓSTICO DO FONE - $(date)"
  echo "--- kernel"; uname -a
  echo "--- placas de som"; cat /proc/asound/cards 2>&1
  echo "--- dispositivos de entrada"; cat /proc/bus/input/devices 2>&1
  echo "--- /dev/input/by-path"; ls -l /dev/input/by-path 2>&1
  echo "--- serviços"
  for s in oga_events set-playback audiopath alsa-state alsa-restore; do
    echo "$s: ativo=$(systemctl is-active "$s" 2>&1) habilitado=$(systemctl is-enabled "$s" 2>&1)"
  done
  echo "--- processos"; ps -eo pid,user,args | grep -iE 'ogage|audiopath|usbdac|amixer' | grep -v grep
  echo "--- mixer completo"; amixer -c 0 contents 2>&1
  echo "--- gpio completo"; sudo cat /sys/kernel/debug/gpio 2>&1
  echo "--- dmesg (som)"
  dmesg 2>&1 | grep -iE 'rk817|multicodec|hp-det|hp_det|headphone|headset|jack|extcon|spk|input:'
} > "$LOG" 2>&1

# Grava, em segundo plano, os eventos de entrada e do kernel durante o teste.
for d in /dev/input/event*; do
  sudo timeout 40 evtest "$d" > "$TMP/$(basename "$d").txt" 2>&1 &
done
sudo timeout 40 udevadm monitor --kernel --property > "$TMP/udev.txt" 2>&1 &
sleep 2

conta 4 "Lendo o estado SEM fone..."
retrato "1 - sem fone (inicial)" >> "$LOG" 2>&1

conta 10 ">>> CONECTE o fone AGORA"
retrato "2 - com fone" >> "$LOG" 2>&1

conta 10 ">>> REMOVA o fone AGORA"
retrato "3 - sem fone (final)" >> "$LOG" 2>&1

diz "Finalizando, aguarde..."
sleep 16
wait

{
  echo
  echo "===== EVENTOS DE ENTRADA DURANTE O TESTE ====="
  for f in "$TMP"/event*.txt; do
    echo "--- $(basename "$f" .txt)"
    grep -E 'Input device name|Event: time' "$f" | grep -vE 'SYN_REPORT|EV_ABS|EV_MSC' | head -60
  done
  echo
  echo "===== EVENTOS DO KERNEL (udev) DURANTE O TESTE ====="
  cat "$TMP/udev.txt"
  echo
  echo "##### FIM"
} >> "$LOG" 2>&1
sync

diz ""
diz "Concluído. Relatório salvo em tools/diag_fone_log.txt"
diz "Desligue o aparelho e coloque o cartão no computador."
sleep 6
exit 0
