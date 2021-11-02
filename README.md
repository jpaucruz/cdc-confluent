# CDC with Confluent - Starter Kit


En este repositorio se puede encontrar una PoC lista para poder empezar a trabajar con Confluent. Va a tener todo lo necesario para poder implementar soluciones de CDC y construir casos de uso en tiempo real.

## Features
Dentro de las features que podrás encontrar en la PoC se encuentran:

- Entorno local usando Docker Compose
- Replicación desde Postgresql hasta MongoDB
- Adminer, para poder realizar cambios en la base de datos origen Postgresql sin necesitar ningún cliente adicional

<br/>

## Puesta en marcha 

La puesta en marcha de toda la infraestructura es muy sencilla. Simplemente, desde la raíz del proyecto, tienes que ejecutar:

```shell
sh build.sh
```

Una vez ejecutado el script, ya estará configurado toda el ecosistema Confluent y las bases de datos origen y destino. Además, el script ya se encarga de instalar las librerías necesarias para hacer uso de los conectores de Postgresql (*source*) como de MongoDB (*sink*).

Se tendrán disponibles las siguientes URLs de interés:

- Kakfa (Broker): http://localhost:9092
- Kafka Connect: http://localhost:8083
- Confluent Control Center: http://localhost:9021
- Adminer: http://localhost:8080

<br/>

## CDC con Confluent

En este punto, si accedemos al Control Center de Confluent, concretamente a la parte que gestiona Kafka Connect, vemos que no hay ningún conector configurado.

<p align="center">
   <img src="doc/img/cc_empty.png" alt="cc connector empty"/>
</p>

Por otro lado, desde el Control Center también podemos acceder para visualizar los *topics* existentes y los mensajes que van llegando. En esta ocación, tampoco vemos ningun *topic* que guarde relación con la solución que queremos implementar.

<p align="center">
   <img src="doc/img/cc_topic_empty.png" alt="cc topic empty"/>
</p>


Esto es un situación normal, ya que todavía no hemos realizado los pasos necesarios para crear la solución de CDC.

<br/>


#### Paso 1. Registrando el conector para Postgresql

El primer paso para construir una solución de CDC con Confluent es el de registrar el conector para indicar que queremos establecer CDC desde un origen a Kafka. En este caso, el origen es Postgresql. 

Para simplificar esta operación, se adjuntan los datos de configuración del conector, los cuales se encuentran en el fichero *connectors/pgsql-connector.json*

```shell
{
  "name": "postgresql-source-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "tasks.max": "1",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "admin",
    "database.password": "admin1",
    "database.dbname" : "cdc",
    "database.server.name": "postgresql",
    "schema.include": "confluent",
    "plugin.name": "pgoutput",
    "publication.autocreate.mode": "filtered",
    "slot.name": "debezium",
    "transforms":"unwrap,RenameField",
    "transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState",
    "transforms.RenameField.type": "org.apache.kafka.connect.transforms.ReplaceField$Value",
    "transforms.RenameField.renames": "id:_id",
    "include.schema.changes": "false",
    "key.converter":"org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schema.registry.url":"http://schema-registry:8081",
    "key.converter.schemas.enable":"false",
    "value.converter":"org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schema.registry.url":"http://schema-registry:8081",
    "value.converter.schemas.enable":"false",
    "after.state.only":"true"
  }
}
```

> NOTA: El detalle sobre las distintas propiedades las puedes encontrar en la [documentación del propio conector](https://www.confluent.io/hub/debezium/debezium-connector-postgresql) en Confluent Hub.

<br/>

Para registrar el conector se puede hacer de dos maneras: 
- Mediante la **API REST** que ofrece Kakfa Connect
- Mediante pasos guiados de la herramienta **Control Center** de Confluent

<br/>

En este caso, vamos a registrar el conector a través de la API de Kafka Connect ya que resulta mucho más sencillo. Para ello, lanzamos la siguiente llamada a Kafka Connect:

```shell
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @pgsql-connector.json
```
Deberíamos recibir como respuesta algo como lo siguiente:

```shell
HTTP/1.1 201 Created
Date: Thu, 04 Nov 2021 05:39:00 GMT
Location: http://localhost:8083/connectors/postgresql-source-connector
Content-Type: application/json
Content-Length: 1119
Server: Jetty(9.4.43.v20210629)

{"name":"postgresql-source-connector","config":{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","tasks.max":"1","database.hostname":"postgres","database.port":"5432","database.user":"admin","database.password":"admin1","database.dbname":"cdc","database.server.name":"postgresql","schema.include":"confluent","plugin.name":"pgoutput","publication.autocreate.mode":"filtered","slot.name":"debezium","transforms":"unwrap,RenameField","transforms.unwrap.type":"io.debezium.transforms.ExtractNewRecordState","transforms.RenameField.type":"org.apache.kafka.connect.transforms.ReplaceField$Value","transforms.RenameField.renames":"id:_id","include.schema.changes":"false","key.converter":"org.apache.kafka.connect.json.JsonConverter","key.converter.schema.registry.url":"http://schema-registry:8081","key.converter.schemas.enable":"false","value.converter":"org.apache.kafka.connect.json.JsonConverter","value.converter.schema.registry.url":"http://schema-registry:8081","value.converter.schemas.enable":"false","after.state.only":"true","name":"postgresql-source-connector"},"tasks":[],"type":"source"}
```

En la respuesta nos está diciendo que el conector se ha creado correctamente (status 201) y que se ha registrado en "http://localhost:8083/connectors/postgresql-source-connector". 

Si accedemos ahora al Control Center de Confluent veremos que nos aparece el conector y que está *running*.

<p align="center">
   <img src="doc/img/cc_pgsql_running.png" alt="pgsql running"/>
</p>

Además, podemos verificar su funcionamiento al comprobar los *topics* exitentes a través del Control Center. Veremos que aparecen *topics* nuevos correspondientes a las tablas de postgresql que se van a monitorizar.

<p align="center">
   <img src="doc/img/cc_topic_pgsql.png" alt="cc topics"/>
</p>

Si accedemos al *topic* ***postgresql.confluent.customers***, veremos que tiene mensajes con los datos de la tabla de postgresql correspondiente.

<p align="center">
   <img src="doc/img/cc_topic_pgsql_messages.png" alt="cc messages"/>
</p>

> NOTA: Estos mensajes no son cambios sino que corresponden a la snapshot inicial que realiza el conector la primera vez que se configura a un origen de datos (son los datos ya existentes en la tabla antes de implementar la solución CDC).

<br/>

Una vez registrado el conector, ya se tiene monitorizada la base de datos postgresql e implementada la solución CDC con Confluent.

<br/>

#### Paso 2. Probar el funcionamiento del conector: Realizando cambios en PostgreSQL

Para probar la solución de CDC implementada, se va a realizar cambios en el origen de datos, la base de datos postgresql, y ver si transmite bien esos cambios a Kafka.

Para ello, accedemos a la [consola de Adminer](http://localhost:8080) e introducimos los datos de conexión a PostgreSQL:

- **Servidor:** postgres
- **User / Pass:** admin / admin1
- **Base de datos:** cdc

<p align="center">
   <img src="doc/img/adminer_config.png" alt="adminer config"/>
</p>
  
Una vez dentro tenemos que seleccionar el esquema.

<p align="center">
   <img src="doc/img/adminer_config_schema.png" alt="adminer schema"/>
</p>

En este momento, estamos en disposición de hacer cualquier acción sobre la tabla *customers*. 

Por ejemplo, vamos a añadir un registro.

<p align="center">
   <img src="doc/img/adminer_add.png" alt="adminer add record"/>
</p>

Por otro lado, vamos a modificar el nombre de un registro existente.

<p align="center">
   <img src="doc/img/adminer_update.png" alt="adminer update record"/>
</p>

Si todo ha ido bien, se habrán propagado los cambios a Kafka. Si volvemos ahora al Control Center y volvemos a entrar al topic *postgresql.confluent.customers* veremos dos mensajes más correspondientes a los cambios realizados

<p align="center">
   <img src="doc/img/cc_topic_pgsql_messages_cdc.png" alt="cdc messages topic"/>
</p>

> NOTA: El formato de los mensajes ha sido modificado para la PoC. En condiciones normales, los eventos de cambio traen muchas más información, como la operación  que se ha realizado en el origen o distintos metadatos.

<br/>

## Paso 3. Implementando caso de uso en tiempo real

Una vez implementada y probada nuestra solución de CDC con Confluent, vamos a implementar un caso de uso muy útil en sistemas productivos. La replicación de datos en tiempo real.

En este caso, vamos a replicar la base de datos postgreSQL a una base de datos MongoDB.

Partimos de que ya somos capaces de detectar los cambios que se han producido en la base de datos origen y transmitirlos a Kafka de forma inmediata, por lo que lo único que tenemos que hacer es registrar otro conector que permita leer los datos de Kafka y llevarlos a la base de datos destino como es MongoDB.

Para ello, simplemente debemos seguir los pasos que hicimos con el conector anterior, por lo que vamos a resumir los pasos a realizar.

En esta ocasión, la configuración para transmitir los datos desde Kafka a MongoDB se encuentra en el fichero *connectors/mongo-connector.json*

```shell
{
  "name": "mongo-sink-connector",
  "config": {
    "topics": "postgresql.confluent.customers",
    "connection.uri": "mongodb://admin:admin1@mongo:27017",
    "database": "cdc",
    "collection": "confluent",
    "connector.class": "com.mongodb.kafka.connect.MongoSinkConnector",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "post.processor.chain": "com.mongodb.kafka.connect.sink.processor.DocumentIdAdder",
    "document.id.strategy": "com.mongodb.kafka.connect.sink.processor.id.strategy.ProvidedInValueStrategy"
  }
}
```

> NOTA: El detalle sobre las distintas propiedades las puedes encontrar en la [documentación del propio conector](https://www.confluent.io/hub/mongodb/kafka-connect-mongodb) en Confluent Hub.

<br/>

Simplemente quedaría registrar el conector utilizando la API de Kafka Connect.

````shell
curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @mongo-connector.json
````

Como en el caso anterior, y si todo ha ido bien, al acceder al Control Center veremos que aparece el nuevo conector y que está *running*.

<p align="center">
   <img src="doc/img/cc_mongo_running.png" alt="mongo running"/>
</p>

Para finalizar, quedaría por verificar el estado de MongoDB y ver si se ha replicado bien los datos y los cambios que hemos realizado en la etapa anterior. Para ello, usaremos cualquier cliente que permita leer una base de datos MongoDB e introducimos los datos de conexión:

- **Servidor:** mongo
- **User / Pass:** admin / admin1
- **Base de datos:** cdc
- **Colección:** Confluent

De esta forma, verificamos que todos los cambios se han escrito de forma correcta.

<p align="center">
   <img src="doc/img/mongo_data.png" alt="mongo data"/>
</p>

<br/>

Dado el resultado satisfactorio, hemos podido implementar una solución de CDC y, apoyándonos de las capacidades de Confluent, implementar una solución en tiempo real que permita la replicación de datos de una base de datos a otra. 

