#!/bin/bash

# Definir el directorio a analizar, usa PWD si no se proporciona un argumento
DIRECTORIO="${1:-$(pwd)}"
SALIDA_JSON="reporte_warningsV5.json"

# Expresión regular para detectar warnings con número (ejemplo: WARNING 301: mensaje)
PATRON_WARNING="(WARNING|Warning|warning) ([0-9]+) : (.+)"
# Expresión regular para detectar fin del mensaje (6 dígitos numéricos al inicio o línea que empieza con *)
PATRON_FIN="^[0-9]{6}|^\*"

# Inicializar estructura JSON
echo "{" > "$SALIDA_JSON"
echo "  \"directorio\": \"$(realpath "$DIRECTORIO")\"," >> "$SALIDA_JSON"
echo "  \"archivos\": [" >> "$SALIDA_JSON"

# Diccionario asociativo para contar warnings por categoría
declare -A WARNINGS_POR_CATEGORIA
TOTAL_WARNINGS=0
ARCHIVOS_PROCESADOS=0

# Procesar cada archivo .txt en el directorio
for archivo in "$DIRECTORIO"/*.txt; do
    if [[ -f "$archivo" ]]; then
        ((ARCHIVOS_PROCESADOS++))
        echo "    {" >> "$SALIDA_JSON"
        echo "      \"nombre\": \"$(basename "$archivo")\"," >> "$SALIDA_JSON"
        echo "      \"warnings\": [" >> "$SALIDA_JSON"

        WARNINGS_ENCONTRADOS=0
        WARNINGS_JSON=""
        LEYENDO_WARNING=0  # Bandera para detectar contenido multi-línea
        MENSAJE_WARNING="" # Acumulador del mensaje multi-línea
        CATEGORIA_ACTUAL=""
        LINEA_INICIO=0

        # Leer el archivo línea por línea con contador
        LINE_NUM=0
        while IFS= read -r linea || [[ -n "$linea" ]]; do
            ((LINE_NUM++))  # Contador de línea

            if [[ "$linea" =~ $PATRON_WARNING ]]; then
                # Si ya estábamos leyendo un warning, guardamos el anterior
                if [[ $LEYENDO_WARNING -eq 1 ]]; then
                    WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"$(echo -e "$MENSAJE_WARNING" | sed ':a;N;$!ba;s/\n/\\n/g')\" },\n"
                    ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
                    ((TOTAL_WARNINGS++))
                    ((WARNINGS_ENCONTRADOS++))
                fi

                # Iniciar captura de un nuevo warning
                LEYENDO_WARNING=1
                LINEA_INICIO=$LINE_NUM
                CATEGORIA_ACTUAL="${BASH_REMATCH[2]}"
                MENSAJE_WARNING="${BASH_REMATCH[3]}"
            
            elif [[ $LEYENDO_WARNING -eq 1 ]]; then
                # Si encontramos el patrón de fin, terminamos este warning
                if [[ "$linea" =~ $PATRON_FIN ]]; then
                    WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"$(echo -e "$MENSAJE_WARNING" | sed ':a;N;$!ba;s/\n/\\n/g')\" },\n"
                    ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
                    ((TOTAL_WARNINGS++))
                    ((WARNINGS_ENCONTRADOS++))
                    LEYENDO_WARNING=0
                else
                    # Agregar la línea al mensaje acumulado
                    MENSAJE_WARNING+="\n$linea"
                fi
            fi
        done < "$archivo"

        # Guardar el último warning si el archivo termina con un mensaje en curso
        if [[ $LEYENDO_WARNING -eq 1 ]]; then
            WARNINGS_JSON+="        { \"linea\": $LINEA_INICIO, \"categoria\": \"$CATEGORIA_ACTUAL\", \"mensaje\": \"$(echo -e "$MENSAJE_WARNING" | sed ':a;N;$!ba;s/\n/\\n/g')\" },\n"
            ((WARNINGS_POR_CATEGORIA["$CATEGORIA_ACTUAL"]++))
            ((TOTAL_WARNINGS++))
            ((WARNINGS_ENCONTRADOS++))
        fi

        # Eliminar la última coma del JSON de warnings si hubo al menos uno
        if [[ $WARNINGS_ENCONTRADOS -gt 0 ]]; then
            WARNINGS_JSON=$(echo -e "$WARNINGS_JSON" | sed '$ s/,$//')
        fi

        # Agregar los warnings al JSON
        echo -e "$WARNINGS_JSON" >> "$SALIDA_JSON"
        echo "      ]," >> "$SALIDA_JSON"
        echo "      \"total_warnings\": $WARNINGS_ENCONTRADOS" >> "$SALIDA_JSON"
        echo "    }," >> "$SALIDA_JSON"
    fi
done

# Eliminar la última coma en la lista de archivos si hubo al menos uno
if [[ $ARCHIVOS_PROCESADOS -gt 0 ]]; then
    sed -i '$ s/,$//' "$SALIDA_JSON"
fi

echo "  ]," >> "$SALIDA_JSON"

# Agregar la tabla de totales por categoría
echo "  \"totales_por_categoria\": {" >> "$SALIDA_JSON"
for categoria in "${!WARNINGS_POR_CATEGORIA[@]}"; do
    echo "    \"$categoria\": ${WARNINGS_POR_CATEGORIA[$categoria]}," >> "$SALIDA_JSON"
done
# Eliminar la última coma de la tabla de totales por categoría si hubo al menos uno
sed -i '$ s/,$//' "$SALIDA_JSON"

echo "  }," >> "$SALIDA_JSON"

# Agregar el total de warnings detectados
echo "  \"total_warnings\": $TOTAL_WARNINGS" >> "$SALIDA_JSON"

echo "}" >> "$SALIDA_JSON"

echo "Reporte generado: $SALIDA_JSON"
