--use minutas_app
--========================================================
--            MANEJO DE PERSONAS/USUARIOS
--========================================================

-- Tabla para personas (aquí entran todos los tipos de usuarios porque son datos básicos)
create table persona(
	per_id UUID primary key default gen_random_uuid(),
    per_identificacion varchar(13) unique not null,
	per_email varchar(255) unique not null,
	per_password_hash varchar(255) unique not null,
	per_nombres varchar(255) unique not null,
	per_apellidos varchar(255) unique not null,
	per_apodo varchar(255) unique not null,
	per_rol varchar(50) default 'Cliente', --Cliente, Abogado, Admin
	per_telefono varchar(10),
	per_estado varchar(50) default 'Activo',
    per_cant_doc_generado integer default 0,
	per_email_vefiricado boolean default false,
	per_fecha_creacion timestamp default current_timestamp,
	per_fecha_modificacion timestamp default current_timestamp
);

-- Tabla para abogados
create table abogado(
	abo_id UUID primary key default gen_random_uuid(),
	per_id UUID references persona(per_id),
	abo_matricula varchar(20) unique not null,
	abo_direccion_estudio TEXT,
	abo_especializacion TEXT[],
	abo_tarifa_hora decimal(10,2),
	abo_tarifa_proyecto decimal(10,2),
    abo_cant_doc_asignados integer default 0
);

--========================================================
--               MANEJO DE DOCUMENTACION
--========================================================

-- Tabla de categorias de documentos
create table categoria_documento(
	catdoc_id UUID primary key default gen_random_uuid(),
	catdoc_nombre varchar(100) not null, 
	catdoc_descripcion text,
	catdoc_estado varchar(20) default 'Activo',
	catdoc_fecha_creacion timestamp default current_timestamp
);

-- Tabla de plantillas
create table plantilla(
	pla_id UUID primary key default gen_random_uuid(),
	catdoc_id UUID references categoria_documento(catdoc_id),
	pla_nombre varchar(255) unique not null,
	pla_contenido TEXT not null, --formato del template
	pla_campos_obligatorios JSONB not null, -- campos obligtorios
	pla_campos_opcionales JSONB, --campos opcionales
	pla_ai_prompts JSONB not null, --Prompts para la generación de la IA
	pla_precio_base decimal(10,2) not null,
	pla_precio_abogado decimal(10,2) not null,
	pla_estado varchar(20) default 'Activo',
	pla_creado_por varchar(50) references persona(per_apodo),
	pla_fecha_creacion timestamp default current_timestamp,
	pla_fecha_modificacion timestamp default current_timestamp
);

--tabla documento
create table documento_legal(
	docle_id UUID primary key default gen_random_uuid(),
	per_id UUID references persona(per_id),
	abo_id UUID references abogado(abo_id),
    pla_id UUID references plantilla(pla_id),
	docle_nombre varchar(200) unique not null,
	docle_contenido TEXT not null, --json con la estructura del documento
    docle_ai_contenido_generado TEXT,
    docle_doc_data JSONB,
    docle_doc_path varchar(500),
    docle_doc_firmado_path varchar(500),
    docle_doc_tamanio integer,
    docle_status varchar(100) default 'Generado por IA', --Generado por IA, Revisado por abogado, Pendiente de pago, Pagado y entregado
    docle_revisiones integer default 0,
    docle_revisado_abogado timestamp,
    docle_fecha_firma timestamp,
    docle_fecha_liberacion timestamp
);

--========================================================
--              MANEJO DE CONVERSACIONES
--========================================================

create table conversacion(
    conv_id UUID primary key default gen_random_uuid(),
    per_id UUID references persona(per_id),
    pla_id UUID references plantilla(pla_id),
    abo_id UUID references abogado(abo_id),
    conv_estado varchar(50) default 'Conversando con IA', -- Conversando con IA, Conversando con Abogado, Finalizada, Inactiva
    conv_intencion varchar(255),
    conv_contexto JSONB, 
    conv_datos_recopilados JSONB,
    conv_porcentaje integer default 0,
    conv_fecha_fin_ia timestamp, --fecha en la que la IA dejó la conversación
    conv_fecha_abogado_ingreso timestamp, -- fecha en la que el abogado envió el primer mensaje
    conv_precio_final decimal (10,2),
    conv_precio_desglose JSONB,
    conv_fecha_inicio timestamp default current_timestamp,
    conv_fecha_fin timestamp,
    conv_ultima_actividad timestamp
);

create table chat_historial(
    chat_id UUID primary key default gen_random_uuid(),
    conv_id UUID references conversacion(conv_id),
    chat_tipo_remitente varchar(50) not null, --Cliente, Abogado, IA, Sistema
    chat_remitente_id UUID references persona(per_id), --Solo para Clientes y Abogados
    chat_tipo_mensaje varchar(50) default 'Texto',
    chat_contenido TEXT not null,
    chat_metadata JSONB,
    chat_version_documento INTEGER,
    chat_leido boolean default false,
    chat_fecha_creacion timestamp default current_timestamp
);


--========================================================
--         MANEJO DE PAGOS Y TRANSACCIONES
--========================================================
create table pago(
    pag_id UUID primary key default gen_random_uuid(),
    per_id UUID references persona(per_id),
    docle_id UUID references documento_legal(docle_id),
    abo_id UUID references abogado(abo_id),
    pag_total decimal (10,2) not null,
    pag_abo_tarifa decimal (10,2) not null,
    pag_servicio decimal (10,2) not null,
    pag_moneda varchar(3) default 'USD',
    pag_estado varchar(50) default 'Pendiente', --Pendiente, Pagado, Fallido, En revisión, Reembolsado
    pag_metodo varchar(50),
    pag_identificador_pago varchar(255),
    pag_identificador_transaccion varchar(255),
    pag_fecha_pago timestamp,
    pag_fecha_creacion timestamp default current_timestamp
);

create table factura (
    fac_id UUID primary key default gen_random_uuid(),
    pag_id UUID references pago(pag_id),
    per_id UUID references persona(per_id),
    abo_id UUID references abogado(abo_id),
    fac_numero varchar(50) unique not null,
    fac_subtotal decimal(10,2) not null,
    fac_iva decimal(10,2) not null,
    fac_estado varchar(50) default 'Pendiente', --Pendiente, Pagado, Fallido, En revisión, Reembolsado
    fac_vencimiento date,
    fac_fecha_creado timestamp default current_timestamp,
    fac_fecha_pago timestamp
);

create table orden_pago(
    id UUID primary key default gen_random_uuid(),
    conv_id UUID references conversacion(conv_id),
    abo_id UUID references abogado(abo_id),
    ordpa_precio_plantila decimal(10,2),
    ordpa_abogado_honorarios decimal (10,2),
    ordpa_servicios_adicionales JSONB,
    ordpa_total decimal(10,2) not null,
    ordpa_estado varchar(50) default 'Pendiente',
    ordpa_fecha_expiracion timestamp,
    pag_id UUID references pago(pag_id),
    ordpa_fecha_creacion timestamp default current_timestamp
);