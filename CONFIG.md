# Configuração

Este projeto é focado em **YouTube** e **YouTube Music** para arquitetura **ARM64-v8a**.

## Configuração Básica

O arquivo `config.toml` já vem configurado para build automático:

```toml
enable-magisk-update = true
parallel-jobs = 1
compression-level = 9

[YouTube]
enabled = true
build-mode = "both"      # "apk", "module" ou "both"
arch = "arm64-v8a"       # Apenas ARM64 é suportado
version = "auto"         # "auto", "latest", "beta", ou versão específica
uptodown-dlurl = "https://youtube.en.uptodown.com/android"

[Music]
enabled = true
build-mode = "both"
arch = "arm64-v8a"
version = "auto"
uptodown-dlurl = "https://youtube-music.en.uptodown.com/android"
```

## Opções Disponíveis

| Opção | Descrição | Valores | Padrão |
|-------|-----------|---------|--------|
| `enabled` | Habilitar/desabilitar build | `true`, `false` | `true` |
| `build-mode` | Tipo de build | `apk`, `module`, `both` | `both` |
| `arch` | Arquitetura | `arm64-v8a` (apenas) | `arm64-v8a` |
| `version` | Versão do app | `auto`, `latest`, `beta`, ou específica | `auto` |
| `excluded-patches` | Patches para excluir | Lista entre aspas | `""` |
| `included-patches` | Patches para incluir | Lista entre aspas | `""` |

## Exemplo: Excluir Patches

```toml
[YouTube]
enabled = true
build-mode = "both"
excluded-patches = "'Hide shorts components' 'Disable shorts on startup'"
```

## Fontes de Download

Usamos **Uptodown** como fonte pois o APKMirror bloqueia requisições automatizadas (erro 403).

## Notas

- Apenas **ARM64-v8a** é suportado neste fork
- Use `version = "auto"` para obter a versão mais recente compatível com os patches
- Os builds são gerados na pasta `build/`
