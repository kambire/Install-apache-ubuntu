# Apache & PHP Installation Script (Ubuntu/Debian)

Este es un script interactivo diseñado para facilitar la instalación y gestión de un servidor Apache con PHP en sistemas **Ubuntu Server 22.04+** y anteriores.

## Características

- 🚀 **Instalación Core**: Apache2 y PHP en un solo paso.
- 📦 **Módulos de Apache**: Menú interactivo ampliado con más de 80 módulos conocidos (`rewrite`, `ssl`, `proxy`, `http2`, etc).
- 🧩 **Extensiones PHP**: Selección masiva de más de 80 extensiones disponibles.
- ➕ **Extensión Personalizada**: Opción para escribir el nombre de cualquier extensión no listada.
- 🌐 **Gestión de Dominios**: Creador de Virtual Hosts automático con rutas personalizadas.
- 🔒 **Soporte SSL (Certbot)**: Configuración automática en nuevos VHosts y opción para agregar SSL a dominios existentes (con detección automática o entrada manual).
- 📋 **Listar/Gestionar VHosts**: Sistema para ver, habilitar o deshabilitar tus sitios existentes.
- 🗑️ **Eliminar Virtual Host**: Opción para borrar permanentemente la configuración y, opcionalmente, la carpeta del sitio.
- 🛠️ **Reparar Permisos (SFTP/SSH)**: Ajusta automáticamente el dueño y permisos para permitir la edición de archivos sin errores de acceso.
- 📂 **Cambio de DocumentRoot**: Permite modificar la ruta por defecto del servidor globalmente.
- 🔄 **Actualización**: Script independiente para mantener las herramientas al día.

---

## 🚀 Instalación Rápida

Para instalar el script en una carpeta `/scripts` en el root de tu servidor Ubuntu, ejecuta el siguiente comando como **root**:

```bash
mkdir -p /scripts && cd /scripts && \
wget https://raw.githubusercontent.com/kambire/Install-apache-ubuntu/main/install_apache.sh && \
wget https://raw.githubusercontent.com/kambire/Install-apache-ubuntu/main/update.sh && \
chmod +x *.sh && \
./install_apache.sh
```

### 📋 Requisitos

- Acceso **root** o permisos de **sudo**.
- Conexión a internet.
- Basado en **Ubuntu** (Probado en Desktop y Server).

---

## 🔄 Cómo Actualizar

Si ya tienes el script instalado, simplemente ejecuta:

```bash
./update.sh
```

---

## 🛠️ Uso del Menú

El script utiliza `whiptail` para una interfaz visual limpia:
1. Navega con las flechas del teclado.
2. Usa la **Barra Espaciadora** para selecionar opciones en las listas de verificación (módulos/extensiones).
3. Presiona **Enter** para confirmar selecciones.
4. Usa **Tab** para moverte entre los botones de "Ok" y "Cancel".

---

Creado por [kambire](https://github.com/kambire)
