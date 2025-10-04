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

    /// @notice propietario del contrato
    address public immutable owner;

    /// @notice Límite por transacción de retiro (en wei)
    uint256 public withdrawLimit = 1e14; 

    /// @notice Mapping para relacionar las direcciones con la información de los usuarios
    mapping(address => uint256) private balances;

    /// @notice Limite global de depositos;
    uint256 public treasuryBalance = 0;

    /// @notice Limite global de depositos;
    uint256 public immutable bankCap;

    /// @notice contador retiros
    uint128 public withdrawalCount = 0;

    //@notice contador depositos
    uint128 public depositosCount = 0;

    /// @notice Indica si el contrato está bloqueado para nuevas transacciones.
    bool private lock = false;

    /// @notice variable para pausar el contrato en situaciones excepcionales
    bool public paused;

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

    /// @notice Errores personalizado para cuando el contrato se encuentra pausado
    error ContractPaused();
    error ContractNotPaused();

    /*//////////////////////////////
            Eventos
    ///////////////////////////////*/

    /// @notice Evento que se emite cuando se realiza un depósito
    event Deposit(address indexed _user, uint256 _amount, uint256 _newBalance);

    /// @notice Evento que se emite cuando se realiza un retiro
    event Withdrawal(address indexed _user, uint256 _amount, uint256 _newBalance);

    /// @notice evento para pausar la operaciones
    event Paused(address indexed account);
    /// @notice evento para despausar las operaciones
    event Unpaused(address indexed account);
    /// @notice evento queSe emite al actualizar el limite de retiros
    event WithdrawLimitChanged(address indexed account, uint256 newWithdrawLimit);

    /*//////////////////////////////
            Modificadores
    ///////////////////////////////*/

    /// @notice Modificador para prevenir la reentrancia
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
    /// @notice Modificador para validar que el llamador es el propietario
    modifier onlyOwner() {
        require(msg.sender == owner, Unauthorized(msg.sender));
        _;
    }
    /// @notice Modificador para verificar si el contrato esta pausado
    modifier onlyWhenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /**
     * @dev Constructor del contrato
     * @param _bankCap El límite máximo de fondos que el banco puede manejar (en wei)
     */
    constructor(uint256 _bankCap) {
        if (_bankCap > 0) {
            bankCap = _bankCap;
            owner = msg.sender;
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
     * @dev Función para depositar ETH en la cuenta del usuario
     */
    function deposit(uint256 _amount) external payable {
        require(_amount == msg.value, CustomError("amount does not match sent value", msg.sender, _amount));
        bool success = depositFallback();
        if (!success) revert CustomError("Deposit failed", msg.sender, msg.value);
    }

    /**
     * @dev Función para retirar ETH de la cuenta del usuario
     * @param amount La cantidad a retirar (en wei)
     */
    function withdraw(uint256 amount) public nonReentrant onlyWhenNotPaused {
        if (amount > 0) {
            // Cache the balance to avoid multiple storage reads
            uint256 userBalance = balances[msg.sender];
            
            if (amount > withdrawLimit) revert CustomError("Withdrawal limit exceeded", msg.sender, amount);
            if (amount > userBalance) revert InsufficientBalance(amount, userBalance);

            // Restar la cantidad retirada al balance del usuario
            //unchecked {
            balances[msg.sender] = userBalance - amount;
            //}

            // Restar el balance de la tesorería
            treasuryBalance -= amount;

            // Transferir la cantidad al usuario
            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert CustomError("failed transfer", msg.sender, amount);

            // Emitir evento de retiro
            emit Withdrawal(msg.sender, amount, userBalance - amount);

            // aumentar contador retiros
            withdrawalCount++;
        } else {
            revert CustomError("invalid amount", msg.sender, amount);
        }
    }

    /// @notice funcion privada para manejar el depósito de ETH en caso de que entre en las funciones fallback
    function depositFallback() private bankCapCheck onlyWhenNotPaused returns (bool) { 
        if (msg.value == 0) return false;
        
        uint256 userBalance = balances[msg.sender];
        
        balances[msg.sender] = userBalance + msg.value;
        
        // emitir evento deDeposito
        emit Deposit(msg.sender, msg.value, userBalance + msg.value);
        
        // aumentar contador depositos
        depositosCount++;
        return true;
    }

    /**
     * @dev Función para modificar el limite de extraccion, solo disponible para el propietario
     * @param _newWithdrawLimit El nuevo límite de extracción (en wei)
     */
    function setWithdrawLimit(uint256 _newWithdrawLimit) external onlyOwner {
        if (_newWithdrawLimit == 0) revert CustomError("Withdraw limit cannot be set to 0", msg.sender, 0);
        withdrawLimit = _newWithdrawLimit;
        emit WithdrawLimitChanged(msg.sender, _newWithdrawLimit);
    }

    /// @notice funcion para pausar el contrato
    function pause() external onlyOwner {
        if (paused) revert ContractNotPaused();
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice funcion para despausar el contrato
    function unpause() external onlyOwner {
        if (!paused) revert ContractPaused();
        paused = false;
        emit Unpaused(msg.sender);
    }

    /*//////////////////////////////
            Fallbacks
    ///////////////////////////////*/

    /// @notice Función para aceptar ETH directo (sin datos)
    receive() external payable {
        bool success = depositFallback();
        if (!success) revert CustomError("receive sin ETH", msg.sender, msg.value);
    }

    /// @notice Fallback para llamadas con datos inesperados
    fallback() external payable {
        bool success = depositFallback();
        if (!success) revert CustomError("Funcion inexistente y sin ETH", msg.sender, msg.value);
    }
}
