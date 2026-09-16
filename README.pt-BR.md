# Omarchy Notify

[Read in English](README.md)

![Preview da gaveta Omarchy Notify](preview.png)

Uma central de notificações keyboard-first para o Omarchy Quattro, com mouse funcionando se você quiser usar. Só se quiser mesmo!

Atalho global sugerido: `SUPER + ALT + N`.

## Como funciona

A gaveta fica ancorada na borda direita da tela e desliza para a esquerda ao abrir. O desktop continua visível ao lado: isto é uma superfície do shell, não um modal centralizado.

Para fechar, use `Esc`, o botão `×`, o sino novamente ou clique em qualquer lugar fora da gaveta.

O Omarchy continua sendo o daemon de notificações. No Omarchy 4.0.3, widgets de terceiros não recebem entradas de notificação pela API pública; por isso, o Omarchy Notify lê os snapshots locais que o daemon nativo já grava e mantém um arquivo privado. Ele não substitui o daemon nem altera o estado de notificações do Omarchy.

## Recursos

- Gaveta lateral à direita e fechamento por clique fora.
- Sino na barra com badge de não lidas.
- Lista cronológica única, busca, seleção por teclado, remoção e `clear all`.
- Busca aparece somente após `/` e bloqueia atalhos enquanto você digita.
- Corpos em texto simples e imagens somente locais.
- Sem telemetria, rede, downloads ou execução arbitrária por conteúdo de notificação.

## Requisitos

- Omarchy com suporte a plugins Quattro e Quickshell 0.3 ou superior.
- `jq`, `file` e `inotifywait` do pacote `inotify-tools`.

## Instalação

Instale pelo repositório público:

```sh
omarchy plugin add https://github.com/LadiesMan0217/omarchy-notify.git --enable
```

Para instalar este checkout:

```sh
cd /caminho/para/omarchy-notify
omarchy plugin validate .
omarchy plugin add "$(pwd)" --enable
```

ID: `caio.omarchy-notify`. A seção padrão da barra é `right`.

## Desinstalação

```sh
omarchy plugin remove caio.omarchy-notify
```

## Uso e atalhos

- Clique no sino ou use o atalho global para abrir/fechar.
- Clique fora da gaveta ou pressione `Esc` para fechar.
- Clique em uma notificação para selecioná-la.

| Tecla | Ação |
| --- | --- |
| `j` / `↓` | Próxima notificação |
| `k` / `↑` | Notificação anterior |
| `g` / `G` | Primeira / última |
| `x` / `d` | Remover a selecionada |
| `Shift+C` | Limpar todas as notificações arquivadas |
| `/` | Abrir e focar a busca |
| `Esc` | Sair da busca; depois fechar a gaveta |
| `?` | Mostrar ajuda de atalhos |

## IPC e atalho global

```sh
omarchy-shell shell toggle caio.omarchy-notify '{}'
omarchy-shell shell summon caio.omarchy-notify '{}'
omarchy-shell shell hide caio.omarchy-notify
```

O manifesto de plugins do Omarchy não possui atalho global nem hook de pós-instalação. Por segurança, a instalação não modifica seu Hyprland. Para optar pelo atalho global, adicione isto a `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + N", "Omarchy Notify", "omarchy-shell shell toggle caio.omarchy-notify '{}'")
```

Depois recarregue o Hyprland:

```sh
hyprctl reload
```

Antes de escolher outro atalho, verifique conflitos:

```sh
omarchy menu keybindings --print
```

## Atualização, remoção e validação

```sh
omarchy plugin update caio.omarchy-notify
omarchy plugin remove caio.omarchy-notify

omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml
omarchy-shell shell rescanPlugins
notify-send "Omarchy Notify" "Teste"
```

## Armazenamento e retenção

O Omarchy Notify mantém uma janela limitada de notificações recentes para evitar crescimento ilimitado de disco e memória.

| Limite | Valor | Descrição |
| --- | --- | --- |
| Máximo de notificações | 500 | Entradas antigas são podadas automaticamente após cada ingestão |
| Tamanho máximo do arquivo | 2 MiB | Rede de segurança para o orçamento total em bytes no disco e memória |
| Tamanho máximo por campo | 2 048 chars | Truncamento aplicado a `app`, `summary`, `body` e `glyph` na ingestão (contado em codepoints Unicode) |
| Máximo de entradas descartadas | 500 | Descarte explícito pelo usuário; as mais antigas são removidas ao atingir o limite |

Todos os limites se aplicam a `~/.local/state/omarchy-notify/entries.jsonl`.
Imagens copiadas de notificações são removidas quando a entrada correspondente é podada, descartada ou limpa.
A poda automática registra um watermark compacto de timestamp+chave para que notificações podadas nunca sejam reingeridas.

## Limitações reais

- Clicar em uma notificação apenas seleciona. A API de terceiros inspecionada não expõe a ação padrão nem dados para abrir o aplicativo, então o plugin não tenta reproduzi-los.
- DND não é exposto para widgets comuns no Omarchy 4.0.3 inspecionado.
- `clear all` e remoção afetam somente o arquivo privado do Omarchy Notify; não apagam nem dispensam notificações do Omarchy.

## Licença

[MIT](LICENSE).
