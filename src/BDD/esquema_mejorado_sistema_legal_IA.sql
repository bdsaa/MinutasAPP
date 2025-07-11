
CREATE TABLE persona (
    per_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    per_identificacion VARCHAR(13) UNIQUE NOT NULL,
    per_email VARCHAR(255) UNIQUE NOT NULL,
    per_password_hash VARCHAR(255) NOT NULL,
    per_nombres VARCHAR(255) NOT NULL,
    per_apellidos VARCHAR(255) NOT NULL,
    per_apodo VARCHAR(255) UNIQUE,
    per_rol VARCHAR(50) DEFAULT 'Cliente' CHECK (per_rol IN ('Cliente', 'Abogado', 'Admin')),
    per_telefono VARCHAR(20),
    per_estado VARCHAR(50) DEFAULT 'Activo' CHECK (per_estado IN ('Activo', 'Inactivo', 'Suspendido')),
    per_cant_doc_generado INTEGER DEFAULT 0,
    per_email_verificado BOOLEAN DEFAULT false,
    per_avatar_url VARCHAR(500),
    per_ultima_conexion TIMESTAMP,
    per_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    per_fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE abogado (
    abo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    per_id UUID NOT NULL REFERENCES persona(per_id) ON DELETE CASCADE,
    
    abo_matricula VARCHAR(20) UNIQUE NOT NULL,
    abo_cedula VARCHAR(13),
    abo_nombres_completos VARCHAR(255),
    abo_direccion_estudio TEXT,
    abo_fecha_inscripcion DATE,
    abo_credencial VARCHAR(10),
    abo_estado_foro VARCHAR(50),
    
    abo_tarifa_hora DECIMAL(10,2),
    abo_tarifa_base DECIMAL(10,2),
    abo_multiplicador_complejidad JSONB,
    abo_tarifa_minima DECIMAL(10,2),
    abo_tarifa_maxima DECIMAL(10,2),

    abo_cant_doc_asignados INTEGER DEFAULT 0,
    abo_cant_doc_completados INTEGER DEFAULT 0,
    abo_rating_promedio DECIMAL(3,2) DEFAULT 0,
    abo_total_reviews INTEGER DEFAULT 0,
    
    abo_disponible BOOLEAN DEFAULT true,
    abo_verificado BOOLEAN DEFAULT false,
    abo_fecha_verificacion TIMESTAMP,
    abo_ultima_actividad TIMESTAMP,

    abo_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    abo_fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categoria_documento (
    catdoc_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    catdoc_nombre VARCHAR(100) NOT NULL, 
    catdoc_descripcion TEXT,
    catdoc_icono VARCHAR(50),
    catdoc_orden INTEGER DEFAULT 0,
    catdoc_estado VARCHAR(20) DEFAULT 'Activo' CHECK (catdoc_estado IN ('Activo', 'Inactivo')),
    catdoc_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE plantilla (
    pla_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    catdoc_id UUID REFERENCES categoria_documento(catdoc_id),
    pla_nombre VARCHAR(255) NOT NULL,
    pla_descripcion TEXT,
    pla_contenido TEXT NOT NULL,
    pla_campos_obligatorios JSONB NOT NULL,
    pla_campos_opcionales JSONB,
    pla_ai_prompts JSONB NOT NULL,
    pla_precio_base DECIMAL(10,2) NOT NULL,
    pla_precio_abogado DECIMAL(10,2) NOT NULL,
    pla_tiempo_estimado INTEGER,
    pla_complejidad VARCHAR(20) DEFAULT 'Media' CHECK (pla_complejidad IN ('Baja', 'Media', 'Alta')),
    pla_requiere_abogado BOOLEAN DEFAULT true,
    pla_max_revisiones INTEGER DEFAULT 2,
    pla_estado VARCHAR(20) DEFAULT 'Activo' CHECK (pla_estado IN ('Activo', 'Inactivo', 'En_Revision')),
    pla_version INTEGER DEFAULT 1,
    pla_plantilla_padre UUID REFERENCES plantilla(pla_id),
    pla_creado_por UUID REFERENCES persona(per_id),
    pla_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pla_fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Tabla de especializaciones
CREATE TABLE especializacion (
    esp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    esp_nombre VARCHAR(100) UNIQUE NOT NULL,
    esp_descripcion TEXT
);

-- Relación abogado-especialización
CREATE TABLE abogado_especializacion (
    abo_id UUID REFERENCES abogado(abo_id) ON DELETE CASCADE,
    esp_id UUID REFERENCES especializacion(esp_id) ON DELETE CASCADE,
    PRIMARY KEY (abo_id, esp_id)
);

CREATE TABLE documento_legal (
    docle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    per_id UUID REFERENCES persona(per_id),
    abo_id UUID REFERENCES abogado(abo_id),
    pla_id UUID REFERENCES plantilla(pla_id),
    docle_nombre VARCHAR(200) NOT NULL,
    docle_contenido_final TEXT,
    docle_ai_contenido_generado TEXT,
    docle_datos_utilizados JSONB,
    docle_archivo_path VARCHAR(500),
    docle_archivo_firmado_path VARCHAR(500),
    docle_archivo_tamanio INTEGER CHECK (docle_archivo_tamanio >= 0),
    docle_tipo_archivo VARCHAR(10) DEFAULT 'PDF',
    docle_tiene_marca_agua BOOLEAN DEFAULT true,
    docle_status VARCHAR(50) DEFAULT 'IA_Generado' CHECK (
        docle_status IN (
            'IA_Generado', 
            'Usuario_Aprobado', 
            'Abogado_Revision', 
            'Pendiente_Pago', 
            'Firmado_Entregado', 
            'Cancelado'
        )
    ),
    docle_revisiones INTEGER DEFAULT 0,
    docle_fecha_ia_generado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    docle_fecha_usuario_aprobado TIMESTAMP,
    docle_fecha_abogado_inicio TIMESTAMP,
    docle_fecha_abogado_completado TIMESTAMP,
    docle_fecha_firmado TIMESTAMP,
    docle_fecha_entregado TIMESTAMP,
    docle_hash_integridad VARCHAR(64),
    docle_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    docle_fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger para tabla persona
CREATE OR REPLACE FUNCTION actualizar_persona_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.per_fecha_modificacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_persona_modificacion
BEFORE UPDATE ON persona
FOR EACH ROW EXECUTE FUNCTION actualizar_persona_modificacion();

-- Trigger para tabla abogado
CREATE OR REPLACE FUNCTION actualizar_abogado_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.abo_fecha_modificacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_abogado_modificacion
BEFORE UPDATE ON abogado
FOR EACH ROW EXECUTE FUNCTION actualizar_abogado_modificacion();

-- Trigger para tabla plantilla
CREATE OR REPLACE FUNCTION actualizar_plantilla_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.pla_fecha_modificacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_plantilla_modificacion
BEFORE UPDATE ON plantilla
FOR EACH ROW EXECUTE FUNCTION actualizar_plantilla_modificacion();

-- Trigger para tabla documento_legal
CREATE OR REPLACE FUNCTION actualizar_documento_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.docle_fecha_modificacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_documento_modificacion
BEFORE UPDATE ON documento_legal
FOR EACH ROW EXECUTE FUNCTION actualizar_documento_modificacion();



CREATE TABLE conversacion (
    conv_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    per_id UUID NOT NULL REFERENCES persona(per_id) ON DELETE CASCADE,
    pla_id UUID REFERENCES plantilla(pla_id),
    abo_id UUID REFERENCES abogado(abo_id),
    
    conv_estado VARCHAR(50) DEFAULT 'IA_Activa' CHECK (
        conv_estado IN (
            'IA_Activa',
            'Usuario_Aprobado',
            'Abogado_Activo',
            'Pago_Pendiente',
            'Completada',
            'Cancelada',
            'Inactiva'
        )
    ),
    
    conv_intencion VARCHAR(255), -- Intención detectada por la IA
    conv_contexto JSONB, -- Contexto general del usuario (geolocalización, área legal, etc.)
    conv_datos_recopilados JSONB, -- Datos que el usuario ha proporcionado hasta el momento
    
    conv_porcentaje_completado INTEGER DEFAULT 0 CHECK (conv_porcentaje_completado >= 0 AND conv_porcentaje_completado <= 100),
    
    conv_fecha_ia_handoff TIMESTAMP, -- Fecha en que la IA transfiere al abogado
    conv_fecha_abogado_ingreso TIMESTAMP,
    
    conv_precio_final DECIMAL(10,2), -- Precio acordado final
    conv_precio_desglose JSONB, -- Detalle del precio: plantilla, revisión, urgencia, etc.
    conv_tiempo_total_minutos INTEGER DEFAULT 0,
    
    conv_rating_cliente INTEGER CHECK (conv_rating_cliente BETWEEN 1 AND 5),
    conv_feedback_cliente TEXT,
    conv_notas_abogado TEXT,
    
    conv_fecha_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    conv_fecha_fin TIMESTAMP,
    conv_ultima_actividad TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE chat_mensaje (
    men_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conv_id UUID NOT NULL REFERENCES conversacion(conv_id) ON DELETE CASCADE,
    
    men_tipo_remitente VARCHAR(20) NOT NULL CHECK (
        men_tipo_remitente IN ('Cliente', 'Abogado', 'IA', 'Sistema')
    ),
    men_remitente_id UUID REFERENCES persona(per_id), -- Solo aplica si es Cliente o Abogado
    
    men_tipo_mensaje VARCHAR(30) DEFAULT 'Texto' CHECK (
        men_tipo_mensaje IN (
            'Texto',
            'Solicitud_Campo',
            'Vista_Previa_Doc',
            'Cotizacion_Precio',
            'Solicitud_Pago',
            'Archivo',
            'Recomendacion',
            'Cambio_Documento'
        )
    ),
    
    men_contenido TEXT NOT NULL,
    men_metadata JSONB, -- Información adicional como tokens IA, relevancia, etc.
    men_campo_nombre VARCHAR(100), -- Si es solicitud de campo específico
    
    men_version_documento INTEGER, -- Para trazabilidad si se hace revisión o edición
    
    -- Para archivos adjuntos
    men_archivo_url VARCHAR(500),
    men_archivo_nombre VARCHAR(255),
    men_archivo_tamanio INTEGER CHECK (men_archivo_tamanio >= 0),
    
    men_es_leido BOOLEAN DEFAULT false,
    men_fecha_leido TIMESTAMP,
    
    men_editado BOOLEAN DEFAULT false,
    men_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    men_fecha_modificacion TIMESTAMP
);

-- Opcional: índice para rendimiento
CREATE INDEX idx_mensaje_conversacion ON chat_mensaje(conv_id);

CREATE TABLE orden_pago (
    ordpag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conv_id UUID NOT NULL REFERENCES conversacion(conv_id) ON DELETE CASCADE,
    abo_id UUID NOT NULL REFERENCES abogado(abo_id),
    per_id UUID NOT NULL REFERENCES persona(per_id),

    ordpag_precio_plantilla DECIMAL(10,2) NOT NULL,
    ordpag_honorarios_abogado DECIMAL(10,2) NOT NULL,
    ordpag_servicios_adicionales JSONB, -- Ej: urgencia, envío físico, revisión extra

    ordpag_total DECIMAL(10,2) NOT NULL,
    ordpag_moneda VARCHAR(3) DEFAULT 'USD',

    ordpag_descripcion TEXT,
    ordpag_estado VARCHAR(50) DEFAULT 'Pendiente' CHECK (
        ordpag_estado IN ('Pendiente', 'Pagado', 'Expirado', 'Cancelado')
    ),
    
    ordpag_fecha_expiracion TIMESTAMP,
    ordpag_codigo_orden VARCHAR(50) UNIQUE,
    ordpag_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice para estado
CREATE INDEX idx_orden_pago_estado ON orden_pago(ordpag_estado);

CREATE TABLE pago (
    pag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ordpag_id UUID NOT NULL REFERENCES orden_pago(ordpag_id) ON DELETE CASCADE,
    per_id UUID NOT NULL REFERENCES persona(per_id),
    docle_id UUID REFERENCES documento_legal(docle_id),
    abo_id UUID REFERENCES abogado(abo_id),

    pag_total DECIMAL(10,2) NOT NULL,
    pag_honorarios_abogado DECIMAL(10,2) NOT NULL,
    pag_comision_plataforma DECIMAL(10,2) NOT NULL,

    pag_moneda VARCHAR(3) DEFAULT 'USD',
    pag_estado VARCHAR(50) DEFAULT 'Pendiente' CHECK (
        pag_estado IN ('Pendiente', 'Procesando', 'Completado', 'Fallido', 'Reembolsado')
    ),

    pag_metodo VARCHAR(50), -- Ej: tarjeta, PayPal, depósito
    pag_proveedor VARCHAR(50), -- Stripe, MercadoPago, etc.
    pag_id_externo VARCHAR(255), -- ID del pago en la pasarela
    pag_id_transaccion VARCHAR(255), -- Referencia bancaria o pasarela
    pag_receipt_url VARCHAR(500),
    pag_refund_id VARCHAR(255), -- Si hubo reembolso

    pag_fecha_pago TIMESTAMP,
    pag_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice para estado
CREATE INDEX idx_pago_estado ON pago(pag_estado);

CREATE TABLE factura (
    fac_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pag_id UUID NOT NULL REFERENCES pago(pag_id) ON DELETE CASCADE,
    per_id UUID NOT NULL REFERENCES persona(per_id),
    abo_id UUID NOT NULL REFERENCES abogado(abo_id),

    fac_numero VARCHAR(50) UNIQUE NOT NULL,
    fac_subtotal DECIMAL(10,2) NOT NULL,
    fac_iva DECIMAL(10,2) DEFAULT 0,
    fac_descuentos DECIMAL(10,2) DEFAULT 0,
    fac_total DECIMAL(10,2) NOT NULL,

    fac_estado VARCHAR(50) DEFAULT 'Emitida' CHECK (
        fac_estado IN ('Emitida', 'Pagada', 'Vencida', 'Anulada')
    ),
    fac_tipo VARCHAR(20) DEFAULT 'Normal' CHECK (
        fac_tipo IN ('Normal', 'Credito', 'Debito')
    ),

    fac_archivo_path VARCHAR(500),
    fac_fecha_emision DATE DEFAULT CURRENT_DATE,
    fac_fecha_vencimiento DATE,
    fac_fecha_pago TIMESTAMP,
    fac_notas TEXT,

    fac_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE validacion (
    val_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    val_tipo_entidad VARCHAR(50) NOT NULL CHECK (
        val_tipo_entidad IN ('Abogado', 'Documento', 'Usuario')
    ),
    val_entidad_id UUID NOT NULL, -- El ID referenciado
    val_tipo_validacion VARCHAR(50) NOT NULL CHECK (
        val_tipo_validacion IN ('Matricula', 'Cedula', 'RUC', 'Email')
    ),
    val_datos_validacion JSONB, -- Entrada enviada a la fuente
    val_es_valido BOOLEAN,
    val_resultado_detalle JSONB, -- Resultado recibido
    val_fecha_validacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    val_fecha_expiracion TIMESTAMP,
    val_validado_por VARCHAR(100) -- Sistema o API usada
);

CREATE TABLE notificacion (
    not_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    per_id UUID NOT NULL REFERENCES persona(per_id),
    not_tipo VARCHAR(50) NOT NULL CHECK (
        not_tipo IN ('Email', 'SMS', 'Push', 'En_App')
    ),
    not_titulo VARCHAR(255) NOT NULL,
    not_mensaje TEXT NOT NULL,
    not_datos JSONB, -- Información adicional, como enlaces, IDs relacionados, etc.

    not_estado VARCHAR(50) DEFAULT 'Pendiente' CHECK (
        not_estado IN ('Pendiente', 'Enviado', 'Entregado', 'Fallido', 'Leido')
    ),
    
    not_fecha_envio TIMESTAMP,
    not_fecha_leido TIMESTAMP,
    not_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE configuracion_sistema (
    conf_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conf_clave VARCHAR(100) UNIQUE NOT NULL,
    conf_valor JSONB NOT NULL,
    conf_descripcion TEXT,
    conf_tipo VARCHAR(50) DEFAULT 'General' CHECK (
        conf_tipo IN ('General', 'Pago', 'IA', 'Email', 'Seguridad')
    ),
    conf_modificado_por UUID REFERENCES persona(per_id),
    conf_fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE log_actividad (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    per_id UUID REFERENCES persona(per_id),
    log_accion VARCHAR(100) NOT NULL, -- Ej: 'Inicio de sesión', 'Edición documento'
    log_tipo_entidad VARCHAR(50),     -- Ej: 'plantilla', 'documento_legal'
    log_entidad_id UUID,
    log_metadata JSONB,               -- JSON con detalles extra

    log_ip_address INET,
    log_user_agent TEXT,
    log_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
