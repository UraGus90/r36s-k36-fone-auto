#!/bin/bash
# Instala a alternância automática entre fone de ouvido e alto-falante (ArkOS K36).
# Cria /usr/local/bin/fone_auto.sh e o serviço fone-auto.service. Nada mais é alterado.
# Para desfazer, rodar fone_auto_remover.sh.

LOG=/roms/tools/fone_auto_log.txt
TELA=/dev/tty1
diz() { printf '%s\n' "$*" > "$TELA" 2>/dev/null; echo "$*" >> "$LOG"; }

printf '\033c' > "$TELA" 2>/dev/null
echo "##### Instalação - $(date)" > "$LOG"
diz "Instalando a troca automática de fone..."

sudo tee /usr/local/bin/fone_auto.sh > /dev/null << 'FIM_DAEMON'
#!/bin/bash
# Alterna a saída de áudio conforme o fone de ouvido:
#   fone conectado  -> Playback Path = HP  (só fone)
#   fone removido   -> Playback Path = SPK (só alto-falante)
# O estado do fone vem do extcon "rk817-sound", que o kernel atualiza pelo pino hp-det.

achar_extcon() {
  local e
  for e in /sys/class/extcon/*; do
    if [ "$(cat "$e/name" 2>/dev/null)" = "rk817-sound" ]; then
      echo "$e/state"
      return
    fi
  done
}

EXT=${FONE_EXTCON:-$(achar_extcon)}
until [ -n "$EXT" ] && [ -r "$EXT" ]; do
  sleep 2
  EXT=${FONE_EXTCON:-$(achar_extcon)}
done

aplicar() { amixer -q -c 0 cset name='Playback Path' "$1" > /dev/null 2>&1; }

atual() {  # devolve SPK, HP ou o índice numérico de outro modo
  local v
  v=$(amixer -c 0 cget name='Playback Path' 2>/dev/null | sed -n 's/^ *: values=//p')
  case "$v" in
    1) echo SPK ;;
    2) echo HP ;;
    *) echo "$v" ;;
  esac
}

ultimo=""
voltas=0
while :; do
  estado=$(< "$EXT")
  if [[ $estado == *HEADPHONE=1* ]]; then alvo=HP; else alvo=SPK; fi

  if [ "$alvo" != "$ultimo" ]; then
    # Mudou: aplica e reaplica 1 s depois, para prevalecer sobre o daemon de atalhos (ogage).
    aplicar "$alvo"
    sleep 1
    aplicar "$alvo"
    ultimo=$alvo
    voltas=0
  else
    voltas=$((voltas + 1))
    if [ "$voltas" -ge 10 ]; then
      # A cada 5 s confere se algo trocou a saída (boot, retorno da suspensão) e corrige.
      voltas=0
      [ "$(atual)" != "$alvo" ] && aplicar "$alvo"
    fi
  fi
  sleep 0.5
done
FIM_DAEMON
sudo chmod 755 /usr/local/bin/fone_auto.sh

sudo tee /etc/systemd/system/fone-auto.service > /dev/null << 'FIM_SERVICO'
[Unit]
Description=Alternancia automatica entre fone de ouvido e alto-falante
After=sound.target set-playback.service 351mp.service

[Service]
Type=simple
ExecStart=/usr/local/bin/fone_auto.sh
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
FIM_SERVICO

sudo systemctl daemon-reload >> "$LOG" 2>&1
sudo systemctl enable fone-auto.service >> "$LOG" 2>&1
sudo systemctl restart fone-auto.service >> "$LOG" 2>&1
sleep 4

ATIVO=$(systemctl is-active fone-auto.service 2>&1)
HABIL=$(systemctl is-enabled fone-auto.service 2>&1)
SAIDA=$(amixer -c 0 cget name='Playback Path' 2>/dev/null | sed -n 's/^ *: values=//p')
{
  echo "servico: ativo=$ATIVO habilitado=$HABIL"
  echo "Playback Path (1=SPK, 2=HP, 3=SPK_HP): $SAIDA"
  for e in /sys/class/extcon/*; do echo "$e nome=$(cat "$e/name" 2>/dev/null)"; cat "$e/state" 2>/dev/null; done
  systemctl status fone-auto.service --no-pager 2>&1 | head -15
} >> "$LOG" 2>&1
sync

if [ "$ATIVO" = "active" ]; then
  diz "Instalado e em execução."
  diz "Teste agora: conecte e remova o fone com um jogo aberto."
else
  diz "ATENÇÃO: o serviço não iniciou (estado: $ATIVO)."
  diz "Detalhes em tools/fone_auto_log.txt"
fi
sleep 6
exit 0
