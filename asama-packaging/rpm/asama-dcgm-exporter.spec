%define _bindir /opt/asama.ai/bin
%define _configdir /opt/asama.ai/config
%define _servicedir /etc/systemd/system
%define debug_package %{nil}
%define _binary_payload w2.xzdio

Name:           asama-dcgm-exporter
Version:        _RPM_VERSION_
Release:        _RPM_RELEASE_%{?dist}
Summary:        Asama AI DCGM Exporter (NVIDIA GPU metrics)
License:        Proprietary

Source0:        dcgm-exporter
Source1:        asama-dcgm-exporter.service
Source2:        asama-dcgm-exporter@.service
Source3:        dcgm-counters-identity.csv
Source4:        dcgm-counters-health.csv
Source5:        dcgm-counters-analysis.csv
Source6:        dcgm-exporter-identity.env
Source7:        dcgm-exporter-health.env
Source8:        dcgm-exporter-analysis.env

Requires:       systemd
Recommends:     asama-host-agent

%description
NVIDIA DCGM metrics exporter for Asama Host Agent.
Install on hosts with NVIDIA GPUs alongside asama-host-agent.
Runs identity/health/analysis instances against one embedded hostengine.

%prep
# Nothing to do here - using direct binary files

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_configdir}
mkdir -p %{buildroot}%{_servicedir}

install -p -m 750 %{SOURCE0} %{buildroot}%{_bindir}/dcgm-exporter
install -p -m 640 %{SOURCE1} %{buildroot}%{_servicedir}/asama-dcgm-exporter.service
install -p -m 640 %{SOURCE2} %{buildroot}%{_servicedir}/asama-dcgm-exporter@.service
install -p -m 640 %{SOURCE3} %{buildroot}%{_configdir}/dcgm-counters-identity.csv
install -p -m 640 %{SOURCE4} %{buildroot}%{_configdir}/dcgm-counters-health.csv
install -p -m 640 %{SOURCE5} %{buildroot}%{_configdir}/dcgm-counters-analysis.csv
install -p -m 640 %{SOURCE6} %{buildroot}%{_configdir}/dcgm-exporter-identity.env
install -p -m 640 %{SOURCE7} %{buildroot}%{_configdir}/dcgm-exporter-health.env
install -p -m 640 %{SOURCE8} %{buildroot}%{_configdir}/dcgm-exporter-analysis.env

%files
%defattr(-,root,root,-)
%dir %attr(750,asama-agent,asama-agent) /opt/asama.ai
%dir %attr(750,asama-agent,asama-agent) %{_bindir}
%dir %attr(750,asama-agent,asama-agent) %{_configdir}
%attr(750,asama-agent,asama-agent) %{_bindir}/dcgm-exporter
%attr(644,root,root) %{_servicedir}/asama-dcgm-exporter.service
%attr(644,root,root) %{_servicedir}/asama-dcgm-exporter@.service
%config(noreplace) %attr(640,asama-agent,asama-agent) %{_configdir}/dcgm-counters-identity.csv
%config(noreplace) %attr(640,asama-agent,asama-agent) %{_configdir}/dcgm-counters-health.csv
%config(noreplace) %attr(640,asama-agent,asama-agent) %{_configdir}/dcgm-counters-analysis.csv
%config(noreplace) %attr(640,asama-agent,asama-agent) %{_configdir}/dcgm-exporter-identity.env
%config(noreplace) %attr(640,asama-agent,asama-agent) %{_configdir}/dcgm-exporter-health.env
%config(noreplace) %attr(640,asama-agent,asama-agent) %{_configdir}/dcgm-exporter-analysis.env

%pre
if ! getent group asama-agent >/dev/null; then
    groupadd --system asama-agent
fi
if ! getent passwd asama-agent >/dev/null; then
    useradd --system \
        --gid asama-agent \
        --no-create-home \
        --shell /sbin/nologin \
        asama-agent
fi

%post
systemctl daemon-reload || echo "ERROR: Failed to reload systemd"

if ls /dev/nvidia[0-9]* >/dev/null 2>&1; then
    echo "[INFO] NVIDIA GPU detected. Enabling asama-dcgm-exporter..."
    systemctl enable asama-dcgm-exporter.service \
        asama-dcgm-exporter@health.service \
        asama-dcgm-exporter@identity.service \
        asama-dcgm-exporter@analysis.service || echo "ERROR: Failed to enable dcgm-exporter services"
    systemctl restart asama-dcgm-exporter.service \
        asama-dcgm-exporter@health.service \
        asama-dcgm-exporter@identity.service \
        asama-dcgm-exporter@analysis.service || echo "ERROR: Failed to restart dcgm-exporter services"
else
    echo "[WARN] No NVIDIA GPU detected. Unit installed but start is gated by ConditionPathExistsGlob."
    systemctl enable asama-dcgm-exporter.service \
        asama-dcgm-exporter@health.service \
        asama-dcgm-exporter@identity.service \
        asama-dcgm-exporter@analysis.service >/dev/null 2>&1 || true
fi

%preun
if [ $1 -eq 0 ]; then
    systemctl --no-reload disable --now \
        asama-dcgm-exporter@identity.service \
        asama-dcgm-exporter@analysis.service \
        asama-dcgm-exporter@health.service \
        asama-dcgm-exporter.service >/dev/null 2>&1 || :
fi

%postun
if [ $1 -eq 0 ]; then
    systemctl daemon-reload >/dev/null 2>&1 || :
fi
