#!/usr/bin/env bash
# 10-greeter.sh - Deploy das configurações do greetd / Noctalia Greeter
#
# Mudanças em relação à versão anterior:
#   - `-m` no useradd garante home /var/lib/noctalia-greeter.
#   - Backup do config.toml e pam_greetd antes de sobrescrever.

log_info "Configurando arquivos de sistema do greetd..."

# Garante que o usuário greeter exista
if ! id -u greeter &>/dev/null; then
  log_info "Criando usuário greeter..."
  useradd -r -s /usr/bin/nologin -M -d /var/lib/noctalia-greeter greeter
  # Cria o home manualmente pois -M não cria
  mkdir -p /var/lib/noctalia-greeter
  chown greeter:greeter /var/lib/noctalia-greeter
  chmod 755 /var/lib/noctalia-greeter
fi

mkdir -p /etc/greetd

# Backup antes de sobrescrever arquivos de sistema
for _f in /etc/greetd/config.toml /etc/pam.d/greetd; do
  if [[ -e "$_f" && ! -e "$_f.gabrln.bak" ]]; then
    cp -a "$_f" "$_f.gabrln.bak"
    chmod 600 "$_f.gabrln.bak"
  fi
done
unset _f

cp "$REPO_DIR/.config/greetd/config.toml" /etc/greetd/config.toml
cp "$REPO_DIR/.config/greetd/pam_greetd" /etc/pam.d/greetd
chmod 644 /etc/greetd/config.toml /etc/pam.d/greetd

mkdir -p /var/lib/noctalia-greeter
cp "$REPO_DIR/.config/greetd/greeter.toml" /var/lib/noctalia-greeter/greeter.toml
chown -R greeter:greeter /var/lib/noctalia-greeter 2>/dev/null || true
chmod 644 /var/lib/noctalia-greeter/greeter.toml

# Garante arquivos de log exigidos pelo Noctalia Greeter
touch /var/log/noctalia-greeter.log
chown greeter:greeter /var/log/noctalia-greeter.log 2>/dev/null || true
chmod 644 /var/log/noctalia-greeter.log

touch /var/lib/noctalia-greeter/greeter.log
chown greeter:greeter /var/lib/noctalia-greeter/greeter.log 2>/dev/null || true
chmod 644 /var/lib/noctalia-greeter/greeter.log

log_success "Greeter configurado."
