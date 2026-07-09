#!/usr/bin/env bash
# 06-curl-tools.sh - Instala ferramentas via curl/sh
#
# Mudanças em relação à versão anterior:
#   - `set -e -o pipefail` no subshell garante que `curl | bash` falhe
#     corretamente se o curl falhar.
#   - `runuser -u` em vez de `sudo -u` (consistente com resto do framework).
#   - Parsing único de tools (1 fork Python por iteração, 5 antes).
#   - Script wrapper em temp file em vez de string interpolada —
#     elimina risco de injection via $install_url e quoting de env vars.
#   - Log file por ferramenta com PID.

log_info "Verificando ferramentas de coding AI..."

# Garante que ~/.local/bin existe para receber os binários instalados via curl
LOCAL_BIN="$USER_HOME/.local/bin"
if [[ ! -d "$LOCAL_BIN" ]]; then
  log_info "Criando $LOCAL_BIN..."
  if ! runuser -u "$REAL_USER" -- bash -c "mkdir -p '$LOCAL_BIN'"; then
    log_warn "Não foi possível criar $LOCAL_BIN. As ferramentas podem falhar ao instalar."
  fi
  chown_user_path "$LOCAL_BIN"
fi

# Lê a lista de ferramentas do manifesto UMA VEZ
tools_json=$(python3 - "$MANIFESTS_DIR/curl-tools.toml" <<'PY'
import sys, json, tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
print(json.dumps(data.get("tools", [])))
PY
)

# Extrai o número de ferramentas sem reinvocar Python
tool_count=$(python3 -c 'import sys, json; print(len(json.load(sys.stdin)))' <<<"$tools_json")

if [[ "$tool_count" -eq 0 ]]; then
  log_warn "Nenhuma ferramenta configurada em curl-tools.toml."
  return 0
fi

# Para cada ferramenta, extrai campos com UMA chamada Python
for i in $(seq 0 $((tool_count - 1))); do
  IFS=$'\t' read -r name install_url env_var env_value \
    binaries_csv fallback_paths_json <<<"$(python3 - "$tools_json" "$i" "$USER_HOME" <<'PY'
import sys, json, os
tools = json.loads(sys.argv[1])
i = int(sys.argv[2])
home = sys.argv[3]
t = tools[i]
bins = t.get("binaries", [])
fallback = t.get("fallback_paths", [])
expanded = []
for fp in fallback:
    e = os.path.expandvars(fp)
    if e.startswith("~"):
        e = home + e[1:]
    expanded.append(e)
print("\t".join([
    t["name"],
    t["install_url"],
    t.get("env_var", ""),
    t.get("env_value", ""),
    ",".join(bins),
    json.dumps(expanded),
]))
PY
)"

  IFS=',' read -ra binaries <<<"$binaries_csv"
  mapfile -t fallback_paths < <(python3 -c 'import sys, json; [print(p) for p in json.load(sys.stdin)]' <<<"$fallback_paths_json")

  already_installed=false
  for bin_name in "${binaries[@]}"; do
    [[ -z "$bin_name" ]] && continue
    if is_command "$bin_name"; then
      already_installed=true
      break
    fi
  done

  for path in "${fallback_paths[@]}"; do
    if [[ -f "$path" ]]; then
      already_installed=true
      break
    fi
  done

  if [[ "$already_installed" == true ]]; then
    log_success "$name já está instalado. Pulando."
    continue
  fi

  log_info "Instalando $name..."

  # Log file por tentativa, com PID para evitar colisão em retries
  _curl_log="$LOGS_DIR/curl-tools-$name-$$.log"
  touch "$_curl_log"
  chown_user_path "$_curl_log" 2>/dev/null || true

  # Escreve um script wrapper em temp file. Variáveis são passadas via
  # ambiente para o runuser, evitando interpolation na string shell.
  _curl_wrapper=$(mktemp -t gabrln-curl-XXXXXX.sh)
  # Permissões restritivas (script contém a URL)
  chmod 700 "$_curl_wrapper"
  cat >"$_curl_wrapper" <<WRAPPER
#!/usr/bin/env bash
set -e -o pipefail
# env vars passam de fora (env_var=env_value), PATH vem do login shell
curl -fsSL "\${CURL_INSTALL_URL}" | bash
WRAPPER

  # Prepara env vars para passar ao runuser. Variáveis de ambiente são
  # passadas de forma segura (sem interpolação em string shell).
  declare -a _curl_env=("CURL_INSTALL_URL=$install_url")
  if [[ -n "$env_var" ]]; then
    _curl_env+=("$env_var=$env_value")
  fi

  # runuser -l carrega profile (PATH correto para o user)
  # bash -lc: login shell com o wrapper
  # </dev/null: isatty() retorna falso para instaladores
  # >>"$_curl_log" 2>&1: captura tudo
  if ! runuser -u "$REAL_USER" -- env "${_curl_env[@]}" bash -lc '
    set -e -o pipefail
    exec bash "$CURL_WRAPPER_PATH" </dev/null
  ' 2>>"$_curl_log" >>"$_curl_log" CURL_WRAPPER_PATH="$_curl_wrapper" -- ; then
    log_warn "$name pode não ter sido instalado corretamente. Veja $_curl_log."
    rm -f "$_curl_wrapper"
    continue
  fi
  rm -f "$_curl_wrapper"

  # Re-verifica
  installed_now=false
  for bin_name in "${binaries[@]}"; do
    [[ -z "$bin_name" ]] && continue
    if is_command "$bin_name"; then
      installed_now=true
      break
    fi
  done
  for path in "${fallback_paths[@]}"; do
    if [[ -f "$path" ]]; then
      installed_now=true
      break
    fi
  done

  if [[ "$installed_now" == true ]]; then
    log_success "$name instalado."
  else
    log_warn "$name pode não ter sido instalado corretamente. Verifique manualmente."
  fi
done

# Limpa variáveis do escopo gabrln
unset _curl_log _curl_wrapper _curl_env

hash -r
log_success "Ferramentas via curl verificadas."
