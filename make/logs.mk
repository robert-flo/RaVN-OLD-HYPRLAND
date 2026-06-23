# ═══════════════════════════════════════════════════════════════
# 📊 DIAGNOSTICS AND LOGS - System health, disk and journal monitoring
# ═══════════════════════════════════════════════════════════════
# 📚 Documentation: docs/src/content/docs/makefile/07-logs.mdx
# 🎯 Purpose: Monitor system status, network, disk usage and journal logs
# ──── Overview: 8 targets for diagnostics, logs and network analysis ────
#
# 🧪 Dry Run (preview without executing):
#    (all targets are read-only / diagnostic — no DRY_RUN needed)

.PHONY: sys-status sys-disk log-net log-watch log-boot log-err log-svc log-net-enhanced

IFACE = $(shell ip route 2>/dev/null | grep '^default' | awk '{print $$5}' | head -n1 || echo 'enp0s31f6')

# === Health and Diagnostics ===

# ═══════════════════════════════════════════════════════════════
# 🏥 SYS-STATUS - Combined dashboard and detailed system status
# ═══════════════════════════════════════════════════════════════
# ──── Reports hostname, OS/kernel version, disk and git state ──────────
sys-status: ## System health dashboard and report
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🏥 sys-status · system health dashboard$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@printf "$(BLUE)  core:$(NC)\n"
	@OS_NAME=$$(grep -E '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo 'Arch Linux'); \
	KERNEL=$$(uname -r); \
	printf "    $(BLUE)hostname:$(NC)  $(GREEN)%s$(NC)\n" "$$(hostname)"; \
	printf "    $(BLUE)os:$(NC)        $(GREEN)%s$(NC)\n" "$$OS_NAME"; \
	printf "    $(BLUE)kernel:$(NC)    $(GREEN)%s$(NC)\n" "$$KERNEL"
	@printf "\n$(BLUE)  storage:$(NC)\n"
	@DISK_ROOT=$$(df -h / 2>/dev/null | tail -1 | awk '{print $$5" used ("$$4" free)"}' || echo 'N/A'); \
	printf "    $(BLUE)disk /:$(NC)    $(GREEN)%s$(NC)\n" "$$DISK_ROOT"; \
	if df -T /home 2>/dev/null | grep -q -v "tmpfs\|devtmpfs"; then \
		DISK_HOME=$$(df -h /home 2>/dev/null | tail -1 | awk '{print $$5" used ("$$4" free)"}' || echo 'N/A'); \
		printf "    $(BLUE)disk /home:$(NC) $(GREEN)%s$(NC)\n" "$$DISK_HOME"; \
	fi
	@printf "\n$(BLUE)  health:$(NC)\n"
	@if git diff-index --quiet HEAD -- 2>/dev/null; then \
		printf "    $(BLUE)git:$(NC)       $(GREEN)✓ clean$(NC)\n"; \
	else \
		printf "    $(BLUE)git:$(NC)       $(YELLOW)⚠ uncommitted changes$(NC)\n"; \
	fi
	@FAILED=$$(systemctl --failed --no-legend 2>/dev/null | wc -l); \
	if [ "$$FAILED" -eq 0 ]; then \
		printf "    $(BLUE)services:$(NC)  $(GREEN)✓ all running$(NC)\n"; \
	else \
		printf "    $(BLUE)services:$(NC)  $(RED)✗ %s failed$(NC)\n" "$$FAILED"; \
	fi
	@if command -v checkupdates >/dev/null 2>&1; then \
		UPDATES=$$(checkupdates 2>/dev/null | wc -l || echo "0"); \
	else \
		UPDATES=$$(pacman -Qu 2>/dev/null | wc -l || echo "0"); \
	fi; \
	if [ "$$UPDATES" -eq 0 ]; then \
		printf "    $(BLUE)updates:$(NC)   $(GREEN)✓ up to date$(NC)\n"; \
	else \
		printf "    $(BLUE)updates:$(NC)   $(YELLOW)⚠ %s pending$(NC)\n" "$$UPDATES"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • disk details:   $(BLUE)make sys-disk$(NC)\n"
	@printf "  • error logs:     $(BLUE)make log-err$(NC)\n"
	@printf "  • live logs:      $(BLUE)make log-watch$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 💾 SYS-DISK - Detailed disk usage report for key partitions
# ═══════════════════════════════════════════════════════════════
# ──── Uses duf if available, falls back to df ────────────────
sys-disk: ## Show disk usage info
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)💾 sys-disk · partition and home usage$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if command -v duf >/dev/null 2>&1; then \
		duf -only local / $(HOME); \
	else \
		printf "$(DIM)  /$(NC)\n"; \
		df -h / | tail -1 | awk '{printf "    size: %s  used: %s  avail: %s  use%%: %s\n",$$2,$$3,$$4,$$5}'; \
		printf "$(DIM)  $(HOME)$(NC)\n"; \
		df -h $(HOME) | tail -1 | awk '{printf "    size: %s  used: %s  avail: %s  use%%: %s\n",$$2,$$3,$$4,$$5}'; \
	fi
	@printf "\n$(DIM)  home content:$(NC)\n"
	@HOME_SIZE=$$(du -sh $(HOME) 2>/dev/null | cut -f1); \
	printf "    $(GREEN)$$HOME_SIZE$(NC)\n"
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • system status:  $(BLUE)make sys-status$(NC)\n"
	@printf "  • error logs:     $(BLUE)make log-err$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 🌐 LOG-NET - Comprehensive network diagnostics
# ═══════════════════════════════════════════════════════════════
# ──── Tests DNS resolution, ping and network throughput ────────
log-net: ## Run comprehensive network diagnostics
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🌐 log-net · network diagnostics$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@printf "$(DIM)  dns status:$(NC)\n"
	@if command -v resolvectl >/dev/null 2>&1; then \
		resolvectl status 2>/dev/null | head -60 | sed 's/^/  /'; \
	else \
		printf "$(YELLOW)  resolvectl not available, checking resolv.conf:$(NC)\n"; \
		cat /etc/resolv.conf | grep -v "^#" | grep -v "^$$" | sed 's/^/    /'; \
	fi
	@printf "\n$(DIM)  latency — cloudflare (1.1.1.1):$(NC)\n"
	@ping -c 5 1.1.1.1 | sed 's/^/  /'
	@printf "\n$(DIM)  latency — google.com:$(NC)\n"
	@ping -c 5 google.com | sed 's/^/  /'
	@printf "\n$(DIM)  throughput (cloudflare 50mb):$(NC)\n"
	@curl -sS -L -o /dev/null --max-time 20 -w "  downloaded: %{size_download} bytes  speed: %{speed_download} B/s  time: %{time_total}s\n" \
		"https://speed.cloudflare.com/__down?bytes=50000000"
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • enhanced diagnostics: $(BLUE)make log-net-enhanced$(NC)\n"
	@printf "  • live logs:            $(BLUE)make log-watch$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📈 LOG-WATCH - Monitor system logs in real-time
# ═══════════════════════════════════════════════════════════════
# ──── Runs journalctl -f (follow mode), Ctrl+C to exit ──────
log-watch: ## Watch system logs in real-time (follow mode)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📈 log-watch · live journal stream$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@printf "$(DIM)  streaming — press $(NC)$(YELLOW)ctrl+c$(NC)$(DIM) to exit$(NC)\n\n"
	@journalctl -f

# ═══════════════════════════════════════════════════════════════
# 📋 LOG-BOOT - Display error and alert logs from the current boot
# ═══════════════════════════════════════════════════════════════
# ──── journalctl -b -p err..alert, last 50 entries ──────────
log-boot: ## Show boot logs
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📋 log-boot · errors from current boot$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@journalctl -b -p err..alert --no-pager | tail -50 || true
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • recent errors:  $(BLUE)make log-err$(NC)\n"
	@printf "  • live stream:    $(BLUE)make log-watch$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📋 LOG-ERR - Display recent error-level logs
# ═══════════════════════════════════════════════════════════════
# ──── Shows last 50 error messages with timestamps ──────────
log-err: ## Show recent error logs
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔴 log-err · recent error-level journal entries$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@ERROR_COUNT=$$(journalctl -p err -n 50 --no-pager 2>/dev/null | wc -l || echo "0"); \
	if [ "$$ERROR_COUNT" -eq 0 ]; then \
		printf "$(GREEN)  ✓ no recent errors — system is clean$(NC)\n"; \
	else \
		printf "$(YELLOW)  ⚠ found $$ERROR_COUNT recent error(s):$(NC)\n\n"; \
		journalctl -p err -n 50 --no-pager || true; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • boot errors:    $(BLUE)make log-boot$(NC)\n"
	@printf "  • service logs:   $(BLUE)make log-svc SVC=<name>$(NC)\n"
	@printf "  • live stream:    $(BLUE)make log-watch$(NC)\n\n"

# ═══════════════════════════════════════════════════════════════
# 📋 LOG-SVC - Display logs for a specific systemd service
# ═══════════════════════════════════════════════════════════════
# ──── Requires SVC=<name> e.g. make log-svc SVC=sshd ───────
log-svc: ## Show logs for specific service (use SVC=name)
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)📋 log-svc · service journal logs$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@if [ -z "$(SVC)" ]; then \
		printf "$(YELLOW)  usage: make log-svc SVC=<service-name>$(NC)\n\n"; \
		printf "$(DIM)  examples:$(NC)\n"; \
		printf "    make log-svc SVC=sshd\n"; \
		printf "    make log-svc SVC=networkmanager\n\n"; \
		printf "$(DIM)  running services:$(NC)\n"; \
		systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | \
			awk '{print "    " $$1}' | head -10 || true; \
		printf "\n"; \
	else \
		if journalctl -u $(SVC) --since "1 hour ago" --no-pager 2>/dev/null | grep -q .; then \
			journalctl -u $(SVC) --since "1 hour ago" -n 100 --no-pager; \
		else \
			printf "$(DIM)  no logs in the last hour — showing older entries:$(NC)\n\n"; \
			journalctl -u $(SVC) -n 50 --no-pager; \
		fi; \
	fi
ifndef EMBEDDED
	@if [ -n "$(SVC)" ]; then printf "\n$(GREEN)  ✓ done$(NC)\n"; fi
endif
	@if [ -n "$(SVC)" ]; then \
		printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"; \
		printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"; \
		printf "  • live stream:  $(BLUE)make log-watch$(NC)\n"; \
		printf "  • recent errors: $(BLUE)make log-err$(NC)\n\n"; \
	fi
# ═══════════════════════════════════════════════════════════════
# 🌐 LOG-NET-ENHANCED - Extended network diagnostics with auto-verification
# ═══════════════════════════════════════════════════════════════
# ──── Checks DNS, firewall, throughput, MTR and TCP optimizations ─
log-net-enhanced: ## Run enhanced network diagnostics with automatic verification
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🌐 log-net-enhanced · full network diagnostics$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
	@printf "$(DIM)  dns configuration & override:$(NC)\n"
	@resolvectl status 2>/dev/null | grep -A 3 "Global" | sed 's/^/    /' || printf "$(YELLOW)    resolvectl not available$(NC)\n"
	@printf "\n$(DIM)  interface dns ($(IFACE)):$(NC)\n"
	@resolvectl status $(IFACE) 2>/dev/null | grep -E "Current DNS Server|DNS Servers|DNS Domain" | sed 's/^/    /' || true
	@printf "\n"
	@if resolvectl status $(IFACE) 2>/dev/null | grep -q "1.1.1.1\|1.0.0.1"; then \
		printf "    $(GREEN)✓ dns configured correctly (using cloudflare)$(NC)\n"; \
	elif resolvectl status $(IFACE) 2>/dev/null | grep -q "179.51.50"; then \
		printf "    $(YELLOW)⚠ using isp dns (179.51.50.x)$(NC)\n"; \
		printf "    $(DIM)run: sudo resolvectl dns $(IFACE) 1.1.1.1 1.0.0.1 9.9.9.9$(NC)\n"; \
	else \
		printf "    $(YELLOW)⚠ dns status unknown or custom$(NC)\n"; \
	fi
	@printf "\n$(DIM)  dns from networkmanager (dhcp):$(NC)\n"
	@nmcli device show $(IFACE) 2>/dev/null | grep -E "IP4.DNS" | sed 's/^/    /' || printf "$(YELLOW)    networkmanager info not available$(NC)\n"
	@if nmcli device show $(IFACE) 2>/dev/null | grep -q "179.51.50"; then \
		printf "    $(DIM)isp dns detected in dhcp (ignored by systemd-resolved)$(NC)\n"; \
	fi
	@printf "\n$(DIM)  dns query performance:$(NC)\n"
	@printf "    $(DIM)note: cloudflare uses DoT/853 — measured with kdig; others use UDP/53$(NC)\n"
	@# ── Cloudflare: medir por DoT con kdig (UDP/53 da timeout con DoT activo) ──
	@if command -v kdig >/dev/null 2>&1; then \
		kdig +tls +time=2 @1.1.1.1 github.com &>/dev/null 2>&1 || true; \
		start=$$(date +%s%3N); \
		result=$$(kdig +tls +time=5 @1.1.1.1 github.com 2>&1); \
		end=$$(date +%s%3N); \
		if echo "$$result" | grep -q "NOERROR"; then \
			ms=$$((end - start)); \
			printf "    %-22s %4s ms $(DIM)(DoT/853)$(NC)\n" "cloudflare (1.1.1.1):" "$$ms"; \
		else \
			printf "    %-22s $(RED)%-9s$(NC) $(DIM)(DoT/853)$(NC)\n" "cloudflare (1.1.1.1):" "timeout"; \
		fi; \
		kdig +tls +time=2 @1.0.0.1 github.com &>/dev/null 2>&1 || true; \
		start=$$(date +%s%3N); \
		result=$$(kdig +tls +time=5 @1.0.0.1 github.com 2>&1); \
		end=$$(date +%s%3N); \
		if echo "$$result" | grep -q "NOERROR"; then \
			ms=$$((end - start)); \
			printf "    %-22s %4s ms $(DIM)(DoT/853)$(NC)\n" "cloudflare (1.0.0.1):" "$$ms"; \
		else \
			printf "    %-22s $(RED)%-9s$(NC) $(DIM)(DoT/853)$(NC)\n" "cloudflare (1.0.0.1):" "timeout"; \
		fi; \
	else \
		printf "    %-22s $(YELLOW)kdig not found$(NC) $(DIM)(install: sudo pacman -S knot-dns)$(NC)\n" "cloudflare:"; \
	fi
	@# ── Quad9, Google e ISP: medir por UDP/53 con dig (no usan DoT forzado) ──
	@for dns in "9.9.9.9:quad9" "8.8.8.8:google"; do \
		server=$$(echo $$dns | cut -d: -f1); \
		name=$$(echo $$dns | cut -d: -f2); \
		time=$$(dig @$$server google.com +noall +stats 2>/dev/null | grep "Query time:" | awk '{print $$4}'); \
		if [ -z "$$time" ]; then time="timeout"; fi; \
		if [ "$$time" = "timeout" ]; then \
			printf "    %-18s $(RED)%s$(NC)\n" "$$name:" "$$time"; \
		else \
			printf "    %-18s %4s ms\n" "$$name:" "$$time"; \
		fi; \
	done
	@if ! sudo iptables -L OUTPUT -n 2>/dev/null | grep -q "179.51.50.203"; then \
		time=$$(dig @179.51.50.203 google.com +noall +stats 2>/dev/null | grep "Query time:" | awk '{print $$4}'); \
		if [ -z "$$time" ]; then time="timeout"; fi; \
		if [ "$$time" = "timeout" ]; then \
			printf "    %-18s $(RED)%s$(NC)\n" "isp (tigo/claro):" "$$time"; \
		else \
			printf "    %-18s %4s ms\n" "isp (tigo/claro):" "$$time"; \
		fi; \
	else \
		printf "    %-18s $(GREEN)blocked$(NC)\n" "isp dns:"; \
	fi
	@printf "\n$(DIM)  firewall dns block status:$(NC)\n"
	@if sudo iptables -L OUTPUT -n 2>/dev/null | grep -q "179.51.50"; then \
		printf "    $(GREEN)✓ isp dns blocked by firewall$(NC)\n"; \
		sudo iptables -L OUTPUT -n 2>/dev/null | grep "179.51.50" | head -4 | sed 's/^/      /'; \
	else \
		printf "    $(YELLOW)⚠ no firewall rules blocking isp dns$(NC)\n"; \
		printf "    $(DIM)run: sudo systemctl restart firewall$(NC)\n"; \
	fi
	@printf "\n$(DIM)  latency — cloudflare (1.1.1.1):$(NC)\n"
	@ping -c 5 1.1.1.1 | sed 's/^/    /'
	@printf "\n$(DIM)  latency — google.com:$(NC)\n"
	@ping -c 5 google.com | sed 's/^/    /'
	@printf "\n$(DIM)  throughput (cloudflare 50mb):$(NC)\n"
	@curl -sS -L -o /dev/null --max-time 20 -w "    downloaded: %{size_download} bytes  speed: %{speed_download} B/s  time: %{time_total}s\n" \
		"https://speed.cloudflare.com/__down?bytes=50000000"
	@printf "\n$(DIM)  speedtest (nearest server):$(NC)\n"
	@if command -v speedtest-cli >/dev/null 2>&1; then \
		speedtest-cli --simple | sed 's/^/    /'; \
	elif command -v speedtest >/dev/null 2>&1; then \
		speedtest --simple | sed 's/^/    /'; \
	else \
		printf "    $(YELLOW)⚠ speedtest-cli not available (install with: sudo pacman -S speedtest-cli)$(NC)\n"; \
	fi
	@printf "\n$(DIM)  route quality (mtr to 1.1.1.1):$(NC)\n"
	@if command -v mtr >/dev/null 2>&1; then \
		mtr -rw 1.1.1.1 -c 50 | sed 's/^/    /'; \
		printf "\n    $(DIM)info: high loss on hop #1 (gateway) is normal - it's an mtr artifact$(NC)\n"; \
	else \
		printf "    $(YELLOW)⚠ mtr not available (install with: sudo pacman -S mtr)$(NC)\n"; \
	fi
	@printf "\n$(DIM)  network interface statistics ($(IFACE)):$(NC)\n"
	@if ip -s link show $(IFACE) >/dev/null 2>&1; then \
		printf "    $(DIM)rx (received):$(NC)\n"; \
		ip -s link show $(IFACE) | grep -A 1 "RX:" | tail -1 | sed 's/^/      /'; \
		printf "    $(DIM)tx (transmitted):$(NC)\n"; \
		ip -s link show $(IFACE) | grep -A 1 "TX:" | tail -1 | sed 's/^/      /'; \
		errors=$$(ip -s link show $(IFACE) | grep -A 1 "RX:" | tail -1 | awk '{print $$3}'); \
		if [ "$$errors" = "0" ]; then \
			printf "    $(GREEN)✓ no reception errors$(NC)\n"; \
		else \
			printf "    $(YELLOW)⚠ $$errors reception errors detected$(NC)\n"; \
		fi; \
	else \
		printf "    $(YELLOW)⚠ interface statistics not available$(NC)\n"; \
	fi
	@printf "\n$(DIM)  tcp optimizations:$(NC)\n"
	@cc=$$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $$3}' || echo "N/A"); \
	if [ "$$cc" = "bbr" ]; then \
		printf "    $(GREEN)✓ tcp bbr enabled$(NC)\n"; \
	else \
		printf "    $(YELLOW)⚠ tcp congestion control: $$cc (recommended: bbr)$(NC)\n"; \
	fi; \
	qdisc=$$(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $$3}' || echo "N/A"); \
	if [ "$$qdisc" = "fq" ]; then \
		printf "    $(GREEN)✓ queue discipline: fq (optimal for bbr)$(NC)\n"; \
	else \
		printf "    $(YELLOW)⚠ queue discipline: $$qdisc$(NC)\n"; \
	fi
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • force cloudflare dns: $(BLUE)sudo resolvectl dns $(IFACE) 1.1.1.1 1.0.0.1 9.9.9.9$(NC)\n"
	@printf "  • check dns override:   $(BLUE)resolvectl status $(IFACE)$(NC)\n"
	@printf "  • verify firewall:      $(BLUE)sudo iptables -L OUTPUT -n | grep 179.51$(NC)\n"
	@printf "  • dot benchmark:        $(BLUE)kdig +tls @1.1.1.1 github.com$(NC)\n"
	@printf "  • gateway check:        $(BLUE)./verify-gateway.sh$(NC)\n"
	@printf "  • basic diagnostics:    $(BLUE)make log-net$(NC)\n\n"
