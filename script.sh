#!/bin/sh

DB_HOST="db"         
DB_USER="sa"         
DB_PASSWORD="DAztl@123!"  
DB_NAME="DaztlDB" 

until /opt/mssql-tools/bin/sqlcmd -S db -U sa -P "Daztl123!" -Q "SELECT 1" &> /dev/null
do
  echo "Esperando a que SQL Server esté disponible..."
  sleep 1
done

echo "Esperando a que la base de datos esté lista..."
echo "Creando la base de datos '$DB_NAME' (si no existe)..."
/opt/mssql-tools/bin/sqlcmd -S "$DB_HOST" -U "$DB_USER" -P "$DB_PASSWORD" -Q "
IF NOT EXISTS (SELECT name FROM master.sys.databases WHERE name = '$DB_NAME')
BEGIN
    CREATE DATABASE [$DB_NAME];
    PRINT 'Base de datos [$DB_NAME] creada correctamente.';
END
ELSE
    PRINT 'La base de datos [$DB_NAME] ya existe.';
"
sleep 15  
echo "Aplicando migraciones..."
python manage.py migrate

echo "Levantando Gunicorn..."
exec gunicorn daztl.wsgi:application --bind 0.0.0.0:8000
