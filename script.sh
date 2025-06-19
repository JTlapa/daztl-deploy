#!/bin/sh
echo "[ODBC Driver 17 for SQL Server]
Driver = /opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so.6.1
UsageCount = 1
" > /etc/odbcinst.ini

# Esperar a que SQL Server esté listo
echo "Esperando a que SQL Server esté disponible..."
MAX_DB_WAIT=60
DB_WAIT_COUNT=0
until /opt/mssql-tools/bin/sqlcmd -S db -U sa -P DAztl123@Secure -Q "SELECT 1" &> /dev/null || [ $DB_WAIT_COUNT -eq $MAX_DB_WAIT ]
do
  echo "Intento $DB_WAIT_COUNT: SQL Server no está disponible aún..."
  DB_WAIT_COUNT=$((DB_WAIT_COUNT+1))
  sleep 2
done

if [ $DB_WAIT_COUNT -eq $MAX_DB_WAIT ]; then
  echo "Error: SQL Server no está disponible después de $MAX_DB_WAIT intentos"
  exit 1
fi

# Crear la base de datos si no existe
echo "Verificando/Creando la base de datos..."
/opt/mssql-tools/bin/sqlcmd -S db -U sa -P DAztl123@Secure -Q "
IF NOT EXISTS (SELECT name FROM master.sys.databases WHERE name = 'DaztlDB')
BEGIN
    CREATE DATABASE DaztlDB;
    PRINT 'Base de datos DaztlDB creada';
END
ELSE
    PRINT 'Base de datos DaztlDB ya existe';
"

# Aplicar migraciones
echo "Aplicando migraciones de Django..."
MAX_MIGRATION_RETRIES=5
MIGRATION_RETRY=0

while [ $MIGRATION_RETRY -lt $MAX_MIGRATION_RETRIES ]; do
    if python manage.py migrate --no-input; then
        echo "Migraciones aplicadas con éxito"
        break
    else
        MIGRATION_RETRY=$((MIGRATION_RETRY+1))
        echo "Error en migraciones (Intento $MIGRATION_RETRY/$MAX_MIGRATION_RETRIES). Reintentando en 5 segundos..."
        sleep 5
    fi
done

if [ $MIGRATION_RETRY -eq $MAX_MIGRATION_RETRIES ]; then
    echo "Error: No se pudieron aplicar las migraciones después de $MAX_MIGRATION_RETRIES intentos"
    exit 1
fi

# Iniciar la aplicación
echo "Iniciando la aplicación Django con Daphne..."
exec daphne -b 0.0.0.0 -p 8000 daztl.asgi:application