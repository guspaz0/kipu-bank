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

    /// @notice Dirección del propietario del contrato
    address public immutable owner;

    /// @notice Dirección de la tesorería
    address public immutable treasury;

    /// @notice Límite por transacción de retiro (en wei)
    uint256 public immutable withdrawLimit; 

    /// @notice Mapping para relacionar las direcciones con la información de los usuarios
    mapping(address => uint256) private balances;

    /// @notice Limite global de depositos;
    uint256 private treasuryBalance;

    /// @notice Limite global de depositos;
    uint256 public bankCap;

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
    error BankCapLimitExceeded(uint256 attemptedDeposit, uint256 bankCap);

    /*//////////////////////////////
            Eventos
    ///////////////////////////////*/

    /// @notice Evento que se emite cuando se realiza un depósito
    event Deposit(address indexed _user, uint256 _amount, uint256 _newBalance);

    /// @notice Evento que se emite cuando se realiza un retiro
    event Withdrawal(address indexed _user, uint256 _amount, uint256 _newBalance);

    /// @notice Evento que se emite cuando el propietario retira fondos de la tesorería
    event TreasuryWithdrawal(address indexed _owner, uint256 _amount);

    /*//////////////////////////////
            Modificadores
    ///////////////////////////////*/

    /// @notice Modificador para verificar si el llamador es el propietario
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }
    /// @notice Modificador para validar que el llamador no sea la dirección cero
    modifier validateSender() {
        if (msg.sender == address(0)) revert Unauthorized(msg.sender);
        _;
    }

    /**
     * @dev Constructor del contrato
     * @param _treasury La dirección de la tesorería
     * @param _bankCap El límite máximo de fondos que el banco puede manejar (en wei)
     * @param _withdrawLimit El límite máximo de retiro por transacción (en wei)
     */
    constructor(address _treasury, uint256 _bankCap, uint256 _withdrawLimit) validateSender {
        if (_treasury == address(0)) revert Unauthorized(_treasury);
        if (_withdrawLimit > 0) {
            owner = msg.sender;
            treasury = _treasury;
            withdrawLimit = _withdrawLimit;
            bankCap = _bankCap;
            treasuryBalance = 0;
        } else {
            revert ValueError(_withdrawLimit);
        }
    }

    /*//////////////////////////////
            Funciones
    ///////////////////////////////*/

    /**
     * @dev Función para hacer un depósito de ETH en la cuenta del usuario
     */
    function deposit() external payable validateSender {
        if (msg.value > 0) {
            // Verificar que el depósito no exceda el límite del banco
            require((treasuryBalance + msg.value) <= bankCap, BankCapLimitExceeded(treasuryBalance+msg.value, bankCap));
            
            treasuryBalance += msg.value;

            // Agregar la cantidad depositada al balance del usuario
            balances[msg.sender] += msg.value;

            // Emitir un evento con la información del depósito
            emit Deposit(msg.sender, msg.value, balances[msg.sender]);
        } else {
            revert CustomError("El valor del deposito debe ser mayor a 0", msg.sender, msg.value);
        }
    }

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
    function withdraw(uint256 amount) external validateSender {
        if (amount > 0) {
            require(amount <= balances[msg.sender], InsufficientBalance(amount, balances[msg.sender]));
            // Restar el monto total (incluyendo el fee) del balance del usuario
            balances[msg.sender] -= amount;

            // Restar el balance de la tesorería
            treasuryBalance -= amount;

            emit Withdrawal(msg.sender, amount, balances[msg.sender]);

            // Transferir la cantidad después del fee al usuario
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, CustomError("Transferencia fallida", msg.sender, amount));
        } else {
            revert CustomError("El valor del deposito debe ser mayor a 0", msg.sender, amount);
        }
    }

    /*//////////////////////////////
            Fallbacks
    ///////////////////////////////*/

    /// @notice Función para aceptar ETH directo (sin datos)
    receive() external payable {
        balances[msg.sender] += msg.value;
        bankCap += msg.value;
        emit Deposit(msg.sender, msg.value, balances[msg.sender]);
    }

    /// @notice Fallback para llamadas con datos inesperados
    fallback() external payable {
        if (msg.value > 0) {
            balances[msg.sender] += msg.value;
            bankCap += msg.value;
            emit Deposit(msg.sender, msg.value, balances[msg.sender]);
        } else {
            revert CustomError("Funcion inexistente y sin ETH", msg.sender, msg.value);
        }
    }
}
