// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
* @title KipuBank
* @author Gustavo R. Paz
* @dev Smart contract para gestionar un banco sencillo donde los usuarios pueden depositar y retirar ETH.
*/
contract KipuBank {

    /*//////////////////////////////
          Variables de estado
    ///////////////////////////////*/

    /// @notice Límite por transacción de retiro (en wei)
    uint256 public immutable withdrawLimit; 

    /// @notice Mapping para relacionar las direcciones con la información de los usuarios
    mapping(address => uint256) private balances;

    /// @notice Limite global de depositos;
    uint256 public treasuryBalance;

    /// @notice Limite global de depositos;
    uint256 public immutable bankCap;

    /// @notice Indica si el contrato está bloqueado para nuevas transacciones.
    bool private lock;

    /*//////////////////////////////
            Errores
    ///////////////////////////////*/

    /// @notice Error personalizado para manejo de fondos insuficientes
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice Error personalizado para manejo de valores no válidos
    error ValueError(uint256 value);

    /// @notice Error personalizado para manejo de errores genéricos con mensaje
    error CustomError(string message, address caller, uint256 value);

    /// @notice Error personalizado para manejo de llamadas no autorizadas
    error Unauthorized(address caller);

    /// @notice Error personalizado para manejo de excedentes del límite del banco
    error BankCapLimitExceeded(string message, address caller, uint256 attemptedDeposit, uint256 bankCap);

    /*//////////////////////////////
            Eventos
    ///////////////////////////////*/

    /// @notice Evento que se emite cuando se realiza un depósito
    event Deposit(address indexed _user, uint256 _amount, uint256 _newBalance);

    /// @notice Evento que se emite cuando se realiza un retiro
    event Withdrawal(address indexed _user, uint256 _amount, uint256 _newBalance);

    /*//////////////////////////////
            Modificadores
    ///////////////////////////////*/

    /// @notice Modificador para validar que el llamador no sea la dirección cero
    modifier validateSender() {
        if (msg.sender == address(0)) revert Unauthorized(msg.sender);
        _;
    }
    /// @notice Modificador para evitar la reentrancia
    modifier nonReentrant() {
        require(lock == false, Unauthorized(msg.sender));
        lock = true;
        _;
        lock = false;
    }
    /// @notice Modificador para verificar si no se ah excedido el limite del banco y actualiza el balance
    modifier bankCapCheck() {
        uint256 newBalance = treasuryBalance + msg.value;
        if (newBalance > bankCap) revert BankCapLimitExceeded("global deposit limit exceeded", msg.sender, msg.value, bankCap);
        treasuryBalance = newBalance;
        _;
    }

    /**
     * @dev Constructor del contrato
     * @param _bankCap El límite máximo de fondos que el banco puede manejar (en wei)
     * @param _withdrawLimit El límite máximo de retiro por transacción (en wei)
     */
    constructor(uint256 _bankCap, uint256 _withdrawLimit) validateSender {
        if (_withdrawLimit > 0 && _bankCap > 0) {
            withdrawLimit = _withdrawLimit;
            bankCap = _bankCap;
            treasuryBalance = 0;
        } else {
            revert CustomError("failed to initialize, check constructor parameters", msg.sender, 0);
        }
    }

    /*//////////////////////////////
            Funciones
    ///////////////////////////////*/

    /**
     * @dev Función para verificar el saldo del usuario
     * @return El saldo del usuario en wei
     */
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    /**
     * @dev Función para retirar ETH de la cuenta del usuario
     * @param amount La cantidad a retirar (en wei)
     */
    function withdraw(uint256 amount) public payable validateSender nonReentrant {
        if (amount > 0) {
            if (amount > withdrawLimit) revert CustomError("Withdrawal limit exceeded", msg.sender, amount);
            if (amount > balances[msg.sender]) revert InsufficientBalance(amount, balances[msg.sender]);

            // Restar la cantidad retirada al balance del usuario
            balances[msg.sender] -= amount;

            // Restar el balance de la tesorería
            treasuryBalance -= amount;

            // Emitir evento de retiro
            emit Withdrawal(msg.sender, amount, balances[msg.sender]);

            // Transferir la cantidad al usuario
            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert CustomError("failed transfer", msg.sender, amount);
        } else {
            revert CustomError("invalid amount", msg.sender, amount);
        }
    }

    /*//////////////////////////////
            Fallbacks
    ///////////////////////////////*/

    /// @notice Función para aceptar ETH directo (sin datos)
    receive() external payable validateSender bankCapCheck {
        if (msg.value > 0) {
            balances[msg.sender] += msg.value;
            emit Deposit(msg.sender, msg.value, balances[msg.sender]);
        } else {
            revert CustomError("receive sin ETH", msg.sender, msg.value);
        }
    }

    /// @notice Fallback para llamadas con datos inesperados
    fallback() external payable validateSender bankCapCheck {
        if (msg.value > 0) {
            balances[msg.sender] += msg.value;
            emit Deposit(msg.sender, msg.value, balances[msg.sender]);
        } else {
            revert CustomError("Funcion inexistente y sin ETH", msg.sender, msg.value);
        }
    }
}
