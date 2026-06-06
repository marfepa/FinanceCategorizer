
import re

def parse_strings(content):
    keys = set()
    matches = re.findall(r'"([^"]+)"\s*=\s*"[^"]+";', content)
    for match in matches:
        keys.add(match)
    return keys

with open('/Users/mariofernandez/Desktop/Economía familiar/FinanceCategorizer/Resources/en.lproj/Localizable.strings', 'r') as f:
    en_keys = parse_strings(f.read())

with open('/Users/mariofernandez/Desktop/Economía familiar/FinanceCategorizer/Resources/es.lproj/Localizable.strings', 'r') as f:
    es_keys = parse_strings(f.read())

print(f"English keys: {len(en_keys)}")
print(f"Spanish keys: {len(es_keys)}")

missing_in_es = en_keys - es_keys
missing_in_en = es_keys - en_keys

if missing_in_es:
    print("\nMissing in Spanish:")
    for key in sorted(missing_in_es):
        print(f'- {key}')
else:
    print("\nNothing missing in Spanish.")

if missing_in_en:
    print("\nMissing in English (Extra in Spanish):")
    for key in sorted(missing_in_en):
        print(f'- {key}')
