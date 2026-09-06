# Chromodoro Flutter — Roadmap

Port do **Chromodoro** (Pomodoro tracker em Python/CustomTkinter/SQLite) para um app
desktop **Flutter Windows**, espelhando as funcionalidades do app original.

**Ferramenta Flutter (fora do PATH):**
```
cmd /c "C:\Users\victo\workspace\flutter\flutter_windows_3.47.2-stable\flutter\bin\flutter.bat <cmd>"
```
- Executável: `build\windows\x64\runner\Release\chromodoro_flutter.exe`
- Executar a partir de `C:\Users\victo\workspace\chromodoro_flutter`
- Antes de rebuildar, **encerrar o processo `chromodoro_flutter`** (evita lock no `sqlite3.dll`).

---

## Concluído

- [x] App Flutter desktop Windows funcional (banco real migrado: 19 projetos, 129 sessões, 3 contribuições em `Documents\chromodoro.db`).
- [x] **Notificações de fim de fase** — toast Windows (`flutter_local_notifications` v22 + `flutter_local_notifications_windows`).
- [x] **System tray + mini view (básico)** — `tray_manager`:
  - Ícone no tray (`.ico` real; o clique esquerdo mostra/oculta a janela).
  - Clique direito abre o menu de contexto (Mostrar/Ocultar, Iniciar/Pausar, Completar fase, Sair).
  - Fechar (X) minimiza para o tray respeitando `closeToTray`; `startInTray` esconde no boot.
  - Tooltip reflete o tempo restante (ticker de 1s).

## Dias de trabalho — padrão verificado

- `flutter analyze` limpo (1 info `prefer_initializing_formals` pré-existente em `db_migrator.dart:17`, manter).
- `flutter test` OK (smoke test).
- `flutter build windows --release` OK.
- Boot do exe e validação visual (tray/notificação).

## Regra de teste (importante, aprendida com bug)

- **NÃO pular direto para telas em testes** (não navegar via código / rotas diretas).
- Seguir sempre o fluxo de UI real: dashboard → card → detalhes/focus → usar os botões e o
  botão de voltar do app. Saltar telas gerou estado inconsistente (sessões órfãs) e bugs que
  confundiram o diagnóstico.

## Integridade de sessões (aprendida com bug grave)

- Uma sessão ativa por projeto, no máximo: `endIncompleteForProject` garante isso em
  `startFocus`/`resumeParked`/`park`.
- Sempre usar leituras defensivas (`.get()` + first, nunca `getSingleOrNull`) para
  "sessão mais recente" — duplicatas faziam `getSingleOrNull` lançar `StateError` e
  projetos ficarem "bomba" (não resume, não play).

---

## Próximos passos

### 1. Focus bar / mini view (próximo)
- Barra virtual sobre/atrás da janela ativa refletindo só o tempo restante + percentual, em modo spotlight.
- Conectar ao `TimerService` (`formattedTime`, estado pomodoro/pausa).
- Manter o foco sem deixar o app inteiro aberto.

### 2. Cosméticos Windows
- Ícone nativo do `.exe` / AppUserModelID (substituir o placeholder; reusar o ícone do tray).
- Instância única / pasta de configurações no AppData.

### 3. Configurações na UI
- Expor e permitir editar as settings (som, `closeToTray`, `startInTray`, tempos) na interface; persistir no SQLite (não hardcoded).

### 4. Paridade de telas com o Python original
- Confirmar que todas as views foram portadas (projetos, sessões, contribuições, stats) e que o CRUD está completo.

### 5. Qualidade e testes
- Expandir cobertura além do smoke test; garantir lint/analyze limpo.

---

## Arquivos relevantes

- `lib/services/tray_service.dart` — `TrayService with TrayListener` (ícone, menu, `popUpContextMenu` no clique direito, helpers de janela).
- `lib/providers/app_providers.dart` — `trayServiceProvider`, `notificationServiceProvider`, `timerServiceProvider`.
- `lib/main.dart` — `_ChromodoroAppState with WindowListener` (close→tray, `startInTray`, ticker do tooltip).
- `lib/services/notification_service.dart` — wrapper flutter_local_notifications v22.
- `lib/services/timer_service.dart` — `TimerService` (`isRunning`, `pause()`, `resume()`, `completePhase()`, `formattedTime`, `state`).
- `lib/models/app_settings.dart` — `soundAlerts`, `closeToTray`, `startInTray`.
- `pubspec.yaml` — `assets/images/tray_icon.ico`; deps: `tray_manager`, `flutter_local_notifications`, `flutter_local_notifications_windows`, `window_manager`.
