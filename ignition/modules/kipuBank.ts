import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Límite de retiro por transacción (en wei)
const WITHDRAW_LIMIT = BigInt(1e18); // 1 ETH

// Límite global del banco (en wei)
const BANK_CAP = BigInt(1e21); // 1000 ETH

export default buildModule("kipuBankModule", (m) => {

  // Dueño o sender del contrato (msg.sender) que se usara para deployar el contrato
  // en este caso se usa la cuenta 0 del hardhat node (hardhat trae 20 cuentas por defecto para testing)
  const owner = m.getAccount(0);
  const bankCap = m.getParameter("bankCap", BANK_CAP);
  const withdrawLimit = m.getParameter("withdrawLimit", WITHDRAW_LIMIT);

  const kipuBank = m.contract("KipuBank",[bankCap, withdrawLimit], { from: owner });

  return { kipuBank };
});
