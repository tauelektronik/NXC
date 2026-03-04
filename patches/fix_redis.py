#!/usr/bin/env python3
"""Fix redis.conf for XC_VM v1.2.16 + KeyDB 6.3.4 compatibility"""

conf_path = '/home/xc_vm/bin/redis/redis.conf'

with open(conf_path, 'r') as f:
    lines = f.readlines()

filtered = []
for line in lines:
    stripped = line.strip()
    stripped_no_comment = stripped.lstrip('#').strip()
    # Remover todas as linhas server-threads e server-thread-affinity (ativas ou comentadas)
    if (stripped_no_comment.startswith('server-threads') or
            stripped_no_comment.startswith('server-thread-affinity')):
        continue
    # Remover lazyfree-lazy-server-delay (invalido no KeyDB 6.3.4)
    if stripped_no_comment.startswith('lazyfree-lazy-server-delay'):
        continue
    filtered.append(line)

content = ''.join(filtered)
if not content.endswith('\n'):
    content += '\n'

# Adicionar server-threads 1 (valor seguro - evita issue #88 e e reconhecido pelo status script)
content += 'server-threads 1\n'
content += '# server-thread-affinity true\n'

with open(conf_path, 'w') as f:
    f.write(content)

print('OK: redis.conf atualizado com server-threads 1 e sem lazyfree-lazy-server-delay')

# Verificar resultado
with open(conf_path, 'r') as f:
    new_lines = f.readlines()
print(f'Total de linhas: {len(new_lines)}')
for i, l in enumerate(new_lines, 1):
    if 'server-thread' in l or 'lazyfree-lazy-server-delay' in l:
        print(f'  Linha {i}: {l.rstrip()}')
