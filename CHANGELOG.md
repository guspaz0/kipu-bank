# [2025-10-04]

- agregado funcion privada para depositos en fallbacks
- agregado contador de depositos y retiros.
- (extra) agregado owner del contrato.
- (extra) agregado funcion para actualzar limite de retiro, restringido unicamente para el propietario.
- (extra) agregado funcionalidad para pausar el contrato.


# [2025-10-05]

- quitar funcion de pause/unpause ya que no estaba en el alcance del proyecto.
- quitar funcion setWithdrawalLimit ya que no estaba en el alcance del proyecto.
- quitar owner del contrato ya que no estaba en el alcance del proyecto.
- Se deja immutable la variable withdrawLimit ya que asi estaba especificado en el alcance del proyecto.
- se agregaron Errores personalizados especificos para cada situacion y se implementaron en los metodos correspondientes.