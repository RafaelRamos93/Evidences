#!/bin/bash

# Iniciar tiempo de ejecución
INICIO=$(date +%s)

# Definir el directorio a analizar, usa PWD si no se proporciona un argumento
DIRECTORIO="${1:-$(pwd)}"
SALIDA_JSON="reporte_warningsV9.json"

# Expresiones regulares
PATRON_WARNING="(WARNING|Warning|warning) ([0-9]+) :"
PATRON_FIN_WARNING="^[[:space:]]*([0-9]{6}|\\*)"

# Inicializar JSON
echo "{" > "$SALIDA_JSON"
echo "  \"directorio\": \"$(realpath "$DIRECTORIO")\"," >> "$SALIDA_JSON"
echo "  \"archivos\": [" >> "$SALIDA_JSON"

ARCHIVOS_PROCESADOS=0
TOTAL_GLOBAL_WARNINGS=0

# Procesar cada archivo .txt en el directorio
for archivo in "$DIRECTORIO"/*.txt; do
    [[ -f "$archivo" ]] || continue  # Saltar si no es un archivo
    ((ARCHIVOS_PROCESADOS++))

    echo "    {" >> "$SALIDA_JSON"
    echo "      \"nombre\": \"$(basename "$archivo")\"," >> "$SALIDA_JSON"
    echo "      \"warnings\": [" >> "$SALIDA_JSON"

    WARNINGS_JSON=""
    declare -A WARNINGS_POR_CATEGORIA
    WARNINGS_ENCONTRADOS=0

    LEYENDO_WARNING=0
    MENSAJE_WARNING=""
    CATEGORIA_ACTUAL=""
    LINEA_INICIO=0

    # Cargar archivo en memoria para mejor rendimiento
    mapfile -t lineas < "$archivo"
    NUM_LINEAS=${#lineas[@]}

    for ((i = 0; i < NUM_LINEAS; i++)); do
        LINEA="${lineas[i]}"
        LINEA_LIMPIA="${LINEA#"${LINEA%%[![:space:]]*}"}"  # Trim izquierda

        if [[ "$LINEA_LIMPIA" =~ $PATRON_WARNING ]]; then
            if ((LEYENDO_WARNING)); then
                MENSAJE_WARNING=$(echo "$MENSAJE_WARNING" | tr -s ' ')  # Trim espacios extras
                WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"${MENSAJE_WARNING//$'\n'/\\n}\" },\n"
                ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
            fi

            LEYENDO_WARNING=1
            LINEA_INICIO=$((i + 1))
            CATEGORIA_ACTUAL="${BASH_REMATCH[2]}"
            MENSAJE_WARNING="$LINEA_LIMPIA"

        elif ((LEYENDO_WARNING)); then
            if [[ "$LINEA_LIMPIA" =~ $PATRON_FIN_WARNING ]]; then
                MENSAJE_WARNING=$(echo "$MENSAJE_WARNING" | tr -s ' ')  # Trim espacios extras
                WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"${MENSAJE_WARNING//$'\n'/\\n}\" },\n"
                ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
                LEYENDO_WARNING=0
            else
                MENSAJE_WARNING+="\n$LINEA"
            fi
        fi
    done

    if ((LEYENDO_WARNING)); then
        MENSAJE_WARNING=$(echo "$MENSAJE_WARNING" | tr -s ' ')  # Trim espacios extras
        WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"${MENSAJE_WARNING//$'\n'/\\n}\" },\n"
        ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
    fi

    for categoria in "${!WARNINGS_POR_CATEGORIA[@]}"; do
        ((TOTAL_GLOBAL_WARNINGS+=WARNINGS_POR_CATEGORIA["$categoria"]))
        ((WARNINGS_ENCONTRADOS+=WARNINGS_POR_CATEGORIA["$categoria"]))
    done

    [[ $WARNINGS_ENCONTRADOS -gt 0 ]] && WARNINGS_JSON="${WARNINGS_JSON%,}"

    echo -e "$WARNINGS_JSON" >> "$SALIDA_JSON"
    echo "      ]," >> "$SALIDA_JSON"
    echo "      \"totales_por_categoria\": {" >> "$SALIDA_JSON"

    for categoria in "${!WARNINGS_POR_CATEGORIA[@]}"; do
        echo "        \"$categoria\": ${WARNINGS_POR_CATEGORIA[$categoria]}," >> "$SALIDA_JSON"
    done
    sed -i '$ s/,$//' "$SALIDA_JSON"

    echo "      }," >> "$SALIDA_JSON"
    echo "      \"total_warnings\": $WARNINGS_ENCONTRADOS" >> "$SALIDA_JSON"
    echo "    }," >> "$SALIDA_JSON"
done

[[ $ARCHIVOS_PROCESADOS -gt 0 ]] && sed -i '$ s/,$//' "$SALIDA_JSON"

echo "  ]," >> "$SALIDA_JSON"
echo "  \"resumen_global\": {" >> "$SALIDA_JSON"
echo "    \"total_warnings\": $TOTAL_GLOBAL_WARNINGS" >> "$SALIDA_JSON"
echo "  }" >> "$SALIDA_JSON"
echo "}" >> "$SALIDA_JSON"

# Calcular tiempo de ejecución
FIN=$(date +%s)
TIEMPO_TOTAL=$((FIN - INICIO))

echo "Reporte generado: $SALIDA_JSON"
echo "Tiempo de ejecución: $TIEMPO_TOTAL segundos"
