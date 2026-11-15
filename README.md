# r36s-k36-fone-auto

Troca automática entre fone de ouvido e alto-falante para clones do R36S (linha K36) com **ArkOS K36**.

Nesses aparelhos o som não muda sozinho ao conectar o fone: a imagem deixa a saída fixa em `SPK_HP` (fone e alto-falante juntos) e, ao conectar o fone, a saída vai para `SPK` (só alto-falante). Este script instala um serviço pequeno que corrige isso:

- fone conectado → som só no fone;
- fone removido → som só no alto-falante.

## Compatibilidade

Testado em um aparelho, com esta configuração:

| Item | Valor |
|---|---|
| Sistema | ArkOS - K36 (08112025), imagem comunitária [AeolusUX/ArkOS-K36](https://github.com/AeolusUX/ArkOS-K36) |
| Kernel | 5.10.160 |
| SoC / codec | RK3326 / RK817 |
| DTB em uso | `rf3536k3ka.dtb` |

O script não depende do painel (tela). Ele precisa de `systemd`, `amixer`, do controle `Playback Path` do RK817 e do extcon `rk817-sound` informando `HEADPHONE=1` quando o fone é conectado.

Nos arquivos `.dtb` dos painéis 1 a 10 do K36, a detecção do fone está declarada no mesmo pino (`GPIO2_C6`), então a leitura do fone deve funcionar em todos. Os painéis 6 a 9 não declaram o pino do amplificador do alto-falante (`spk-con`); neles não foi testado se o alto-falante é silenciado com o fone conectado.

Não é necessário no R36S original com ArkOS oficial (kernel 4.4), em que a troca automática já funciona.

## Instalação

1. Baixe `fone_auto_instalar.sh` na [página de releases](../../releases/latest).
2. Com o cartão no computador, copie o arquivo para a pasta `tools` da partição `EASYROMS`.
3. Coloque o cartão no aparelho e ligue.
4. Abra **Options → Tools → fone_auto_instalar**.
5. Aguarde a mensagem "Instalado e em execução".

A troca leva até cerca de 1 segundo depois de conectar ou remover o fone. O resultado da instalação fica em `tools/fone_auto_log.txt`.

Os arquivos precisam manter quebra de linha LF. Se for editar no Windows, use um editor que preserve isso.

## Remoção

Copie `fone_auto_remover.sh` para a mesma pasta `tools` e rode em **Options → Tools → fone_auto_remover**. Ele apaga o serviço e devolve a saída ao modo original da imagem (`SPK_HP`).

## Como funciona

O instalador cria dois arquivos no sistema e não altera mais nada (nem o `ogage`, nem o `.dtb`, nem os serviços existentes):

- `/usr/local/bin/fone_auto.sh`
- `/etc/systemd/system/fone-auto.service`

O serviço lê o estado do fone em `/sys/class/extcon/*/state` (extcon de nome `rk817-sound`) duas vezes por segundo e ajusta o `Playback Path` para `HP` ou `SPK`. Depois de cada mudança ele reaplica o valor 1 segundo mais tarde, para prevalecer sobre o daemon de atalhos (`ogage`), e a cada 5 segundos confere se algo regravou a saída (boot, retorno da suspensão).

Uma reinstalação do ArkOS apaga o serviço; basta rodar o instalador de novo.

## Diagnóstico

Se não funcionar no seu aparelho, `diag_fone.sh` ajuda a descobrir o motivo. Ele não altera nenhuma configuração: lê o estado do áudio sem fone, com fone e sem fone de novo, e grava um relatório em `tools/diag_fone_log.txt`.

1. Copie `diag_fone.sh` para a pasta `tools` e rode em **Options → Tools → diag_fone**, com o fone desconectado.
2. Conecte e remova o fone quando a tela pedir (10 segundos para cada).
3. Abra uma issue anexando o `diag_fone_log.txt`.

No relatório, o que importa é a seção `extcon` dos três retratos: se `HEADPHONE` não passa a `1` com o fone conectado, o kernel não está detectando o fone e este script não resolve.

## Licença

MIT. Uso por conta e risco; faça backup do cartão antes de alterar o sistema.
