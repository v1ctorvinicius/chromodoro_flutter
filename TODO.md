# Chromodoro Flutter — TODO

## Bugs conhecidos

### Críticos

- [ ] **Pause/resume da focus bar não atualiza visual** — ao pausar, a barra não muda de cor (verde→laranja). Botões podem não estar disparando corretamente.
- [ ] **Tray icon play/pause não alterna** — o callback `onToggleTimer` pode não estar conectado ao timer corretamente, ou o estado não propagou.
- [ ] **Timer reinicia toda vez que clica play** — ao invés de resumir a sessão interrompida, cria uma nova. O botão "play" no card do projeto chama `startFocus()` em vez de `resume()`.
- [ ] **"End session" → "Register" não faz nada** — o `registerInterrupted()` pode estar falhando silenciosamente ou o fluxo de review não está conectado.
- [ ] **Edição de projeto não salva** — o `ProjectFormDialog` pode estar passando dados incompletos ou o `update()` no repository pode estar com bug.

### Médios

- [ ] **Falta botão de voltar na tela de foco** — ao pressionar Esc, volta pro dashboard. Não há navegação de volta para a tela de detalhes do projeto.
- [ ] **Focus bar não tem botão de navegar para tela de foco** — seria útil um atalho para ir direto ao timer.

### Baixos

- [ ] **Ícone do tray não muda de cor** — precisa de .ico variados (verde/laranja/cinza) ou tinting.
- [ ] **Note model duplicado** — `models/note.dart` e `models/project.dart` definem a mesma classe `Note`.
- [ ] **shared_preferences não utilizado** — dependência no pubspec mas settings usam Drift.

## Funcionalidades a implementar (Roadmap)

- [ ] **Focus bar / mini view** — ✅ parcial (barra criada, bugs pendentes)
- [ ] **Cosméticos Windows** — ícone nativo do .exe, instância única, pasta AppData
- [ ] **Configurações na UI** — expor settings (já existe SettingsDialog, validar persistência)
- [ ] **Paridade de telas com Python** — confirmar CRUD completo
- [ ] **Qualidade e testes** — expandir cobertura além do smoke test
