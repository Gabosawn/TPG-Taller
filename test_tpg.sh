#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:4000"

echo -e "${BLUE}=== TPG Mensajería - Test CLI ===${NC}\n"

# Función para hacer requests
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -e "${YELLOW}$description${NC}"
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Success (HTTP $http_code)${NC}"
        echo "$body" | jq .
    else
        echo -e "${RED}✗ Error (HTTP $http_code)${NC}"
        echo "$body"
    fi
    echo ""
}

# Esperar a que el servidor esté listo
echo -e "${BLUE}Esperando que el servidor esté listo...${NC}"
sleep 3

# 1. Loguear usuarios
make_request "POST" "/login" '{"usuario": "juan"}' "1. Logueando usuario 'juan'"
make_request "POST" "/login" '{"usuario": "maria"}' "2. Logueando usuario 'maria'"
make_request "POST" "/login" '{"usuario": "pedro"}' "3. Logueando usuario 'pedro'"

# 2. Listar usuarios activos
make_request "GET" "/usuarios" "" "4. Listando usuarios activos"

# 3. Enviar mensajes
make_request "POST" "/enviar" '{"de": "juan", "para": "maria", "mensaje": "Hola Maria!"}' "5. Juan envía mensaje a María"
make_request "POST" "/enviar" '{"de": "maria", "para": "juan", "mensaje": "¡Hola Juan! ¿Cómo estás?"}' "6. María responde a Juan"
make_request "POST" "/enviar" '{"de": "pedro", "para": "maria", "mensaje": "¡Hola a todos!"}' "7. Pedro envía mensaje a María"

# 4. Leer mensajes
make_request "GET" "/mensajes/maria" "" "8. Leyendo mensajes de María"
make_request "GET" "/mensajes/juan" "" "9. Leyendo mensajes de Juan"
make_request "GET" "/mensajes/pedro" "" "10. Leyendo mensajes de Pedro"

# 5. Probar error: usuario no existente
make_request "POST" "/enviar" '{"de": "juan", "para": "inexistente", "mensaje": "Hola"}' "11. Probando envío a usuario inexistente"

echo -e "${BLUE}=== Pruebas completadas ===${NC}"
```

Haz el script ejecutable:
```bash
chmod +x test_tpg.sh
```