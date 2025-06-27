FROM ubuntu:22.04

RUN apt update && apt install -y xl2tpd ppp iproute2 iptables curl

RUN mkdir -p /var/run/xl2tpd

COPY xl2tpd.conf /etc/xl2tpd/xl2tpd.conf
COPY options.xl2tpd /etc/ppp/options.xl2tpd
COPY chap-secrets /etc/ppp/chap-secrets

CMD ["xl2tpd", "-D"]
