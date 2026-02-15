```bash
curl -k -H "Host: myapp.local" https://192.168.29.81

echo '192.168.29.81 myapp.local' > /etc/hosts

curl -k https://myapp.local
```