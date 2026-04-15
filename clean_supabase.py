import sys
with open('Seizcare/Services/SupabaseService.swift', 'r') as f:
    lines = f.readlines()

new_lines = lines[:220] + lines[472:562] # keep lines 1-220 (0-indexed 0 to 219), then keep "}" at 472, then DTOs up to UserDTO (562)

with open('Seizcare/Services/SupabaseService.swift', 'w') as f:
    f.writelines(new_lines)
