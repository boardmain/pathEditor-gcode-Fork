import re
import math

def parse_coords(line):
    x_match = re.search(r'X([\d.]+)', line)
    y_match = re.search(r'Y([\d.]+)', line)
    if x_match and y_match:
        return float(x_match.group(1)), float(y_match.group(1))
    return None

def distance(p1, p2):
    return math.sqrt((p1[0]-p2[0])**2 + (p1[1]-p2[1])**2)

with open('output/prova.gcode', 'r') as f:
    lines = f.readlines()

# Trova l'ultimo punto di ogni path
last_points = []
for i, line in enumerate(lines):
    if 'G0 Z0.0 ; pen up' in line and i > 20:
        # Cerca indietro per trovare l'ultimo G1
        for j in range(i-1, max(0, i-50), -1):
            if lines[j].startswith('G1'):
                coords = parse_coords(lines[j])
                if coords:
                    last_points.append((i, coords))
                    break

print(f'Trovati {len(last_points)} path')
print()
for i in range(len(last_points)-1):
    p1 = last_points[i][1]
    p2 = last_points[i+1][1]
    dist = distance(p1, p2)
    marker = " <-- NUOVO GRUPPO" if dist > 20 else ""
    print(f'Path {i+1} -> Path {i+2}: distanza = {dist:.1f}mm{marker}')
