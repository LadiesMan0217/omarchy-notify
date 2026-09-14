# Omarchy Notify

Central de notificações minimalista e keyboard-first para o shell Quattro do Omarchy. Ela abre como uma gaveta lateral pela direita, mantendo o desktop visível, e usa os tokens nativos de `Color`, `Style`, bordas, espaçamento e fontes do tema ativo.

> Placeholder de preview: capture `preview.png` em uma sessão real antes de publicar.

## Compatibilidade importante

Na instalação investigada — Omarchy 4.0.3-1 e Quickshell 0.3.1 — um `bar-widget` de terceiro comum recebe uma fachada sem serviços. O proxy restrito de `omarchy.notifications` (`doNotDisturb` e `setDoNotDisturb()`) é reservado para o bar completo e clones confiáveis específicos de indicadores. Não existe API de entradas de notificação para este plugin; `pendingModel` e `pastModel` não existem no serviço instalado.

Por isso, nesta versão, a gaveta, IPC, tema e estado vazio funcionam; a listagem, badge, DND, busca, ações e remoção ficam indisponíveis de forma segura. O plugin detecta uma futura API oficial de entradas e ativa esses recursos sem alterar o modelo original. Ele não contorna o isolamento do shell.

## Instalação

Quando houver repositório publicado:

```sh
omarchy plugin add <REPOSITORY_URL> --enable
```

Para instalar este checkout após validar:

```sh
omarchy plugin validate .
omarchy plugin add "$(pwd)" --enable
```

ID: `caio.omarchy-notify`. A seção padrão é `right`.

## Uso e atalhos

- Clique esquerdo no sino: abre/fecha.
- Clique direito e o controle DND só alternam Não Perturbe quando a versão do Omarchy concede essa capacidade a widgets de terceiros; 4.0.3 não concede.
- `j`/`↓`, `k`/`↑`, `g`/`G`, `Enter`, `d`/`x`, `/`, `Esc`, `Tab`/`h`/`l`, `D` e `?` seguem os comportamentos descritos no [README em inglês](README.md#usage) quando a API oficial de entradas estiver disponível.

## IPC e atalho global

```sh
omarchy-shell shell toggle caio.omarchy-notify '{}'
omarchy-shell shell summon caio.omarchy-notify '{}'
omarchy-shell shell hide caio.omarchy-notify
```

O projeto não altera `~/.config/hypr/bindings.lua`. A sintaxe local atual é:

```lua
o.bind("SUPER + ALT + N", "Omarchy Notify", "omarchy-shell shell toggle caio.omarchy-notify '{}'")
```

Antes de usar `SUPER + N`, execute `omarchy menu keybindings --print` e confira conflito. `SUPER + ALT + N` é a alternativa recomendada.

## Desenvolvimento

```sh
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
omarchy-shell shell rescanPlugins
```

Não há `Service.qml` próprio, polling, telemetria, rede, downloads ou escrita de arquivos. O Omarchy continua sendo o único daemon de notificações.

## Licença

[MIT](LICENSE).
