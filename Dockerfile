FROM pydio/cells:latest

# Railway bootstrap. The upstream entrypoint is kept: it is what decides between
# `cells configure` (first boot, reads CELLS_INSTALL_YAML) and `cells start`.
COPY railway-entrypoint.sh /opt/pydio/bin/railway-entrypoint.sh
RUN chmod 0755 /opt/pydio/bin/railway-entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/opt/pydio/bin/railway-entrypoint.sh"]
CMD ["cells", "start"]
