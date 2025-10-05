import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.connect();

const BANK_CAP = BigInt(1e15); // 0.001 ETH

describe("kipuBank", async function () {
  async function kipuBankFixture() {
    const [owner, user1, user2, user3, user4, user5, user6] = await ethers.getSigners();
    const kipubank = await ethers.deployContract("KipuBank", [BANK_CAP], { from: owner });
    await kipubank.waitForDeployment();
    return { kipubank, owner, user1, user2, user3, user4, user5, user6 };
  }

  describe("Despliegue", async function () {
    it("Debería establecer el límite del banco correctamente", 
      async function () {
        const { kipubank } = await networkHelpers.loadFixture(kipuBankFixture);
        expect(await kipubank.bankCap()).to.equal(BANK_CAP);
      }
    );
  });

  describe("Transacciones", function () {
    it("Debería permitir a los usuarios depositar dentro del límite del banco (deposito con fallbacks)", async function () {
      const { kipubank, user1, user2, user3 } = await networkHelpers.loadFixture(kipuBankFixture);

      // User1 deposits  0.0004 ETH
      const depositAmount1 = ethers.parseEther("0.0004");

      await expect(() =>
        user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount1 })
      ).to.changeEtherBalances(ethers,[user1, kipubank], [-depositAmount1, depositAmount1]);

      // User2 deposits 0.0003 ETH
      const depositAmount2 = ethers.parseEther("0.0003");
      await expect(() =>
        user2.sendTransaction({ to: kipubank.getAddress(), value: depositAmount2 })
      ).to.changeEtherBalances(ethers, [user2, kipubank], [-depositAmount2, depositAmount2]);

      // User3 deposits 0.0002 ETH
      const depositAmount3 = ethers.parseEther("0.0002");

      await expect(() =>
        user3.sendTransaction({ to: kipubank.getAddress(), value: depositAmount3 })
      ).to.changeEtherBalances(ethers, [user3, kipubank], [-depositAmount3, depositAmount3]);

      // Total deposits should be 900 ETH, which is within the bank cap of 1000 ETH
      expect(await kipubank.treasuryBalance()).to.equal(depositAmount1 + depositAmount2 + depositAmount3);
    });

    it("No debería permitir a los usuarios depositar más del límite del banco (deposito con fallbacks)",
      async function () {
        const { kipubank, user1, user2, user3, user4 } = await networkHelpers.loadFixture(kipuBankFixture);

        // User1 deposits 0.0004 ETH
        const depositAmount1 = ethers.parseEther("0.0004");

        await expect(() =>
          user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount1 })
        ).to.changeEtherBalances(ethers,[user1, kipubank], [-depositAmount1, depositAmount1]);

        // User2 deposits 0.0003 ETH
        const depositAmount2 = ethers.parseEther("0.0003");
        await expect(() =>
          user2.sendTransaction({ to: kipubank.getAddress(), value: depositAmount2 })
        ).to.changeEtherBalances(ethers, [user2, kipubank], [-depositAmount2, depositAmount2]);

        // User3 deposits  0.0004 ETH
        const depositAmount3 = ethers.parseEther("0.0004");

        const bankCap = await kipubank.bankCap()

        await expect(
          user3.sendTransaction({ to: kipubank.getAddress(), value: depositAmount3 })
        ).to.be.revertedWithCustomError(kipubank, "BankCapLimitExceeded")
          .withArgs("global deposit limit exceeded", user3.address, depositAmount3, bankCap);

        expect(await kipubank.treasuryBalance()).to.be.lessThanOrEqual(bankCap);

    });

    it("debería permitir a los usuarios retirar sus fondos (deposito con fallbacks)",
      async function () {
        const { kipubank, user1, user2, user3 } = await networkHelpers.loadFixture(kipuBankFixture);

        // User1 deposits  0.0004 ETH
        const depositAmount1 = ethers.parseEther("0.0004");
        await user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount1 })

        const withdrawalAmount = ethers.parseEther("0.0001");

        await expect(() =>
          kipubank.connect(user1).withdraw(withdrawalAmount)
        ).to.changeEtherBalances(ethers, [user1, kipubank], [withdrawalAmount, -withdrawalAmount]);
      }
    );

    it("debería denegar a los usuarios retirar más del límite de retiro (deposito con fallbacks)",
      async function () {
        const { kipubank, user1, user2, user3 } = await networkHelpers.loadFixture(kipuBankFixture);

        // User1 deposits 0.0004 ETH
        const depositAmount1 = ethers.parseEther("0.0004");
        await user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount1 })

        const withdrawalAmount = ethers.parseEther("0.0002");

        await expect(
          kipubank.connect(user1).withdraw(withdrawalAmount)
        ).to.be.revertedWithCustomError(kipubank, "WithdrawalLimitExceeded")
        .withArgs(user1.address, withdrawalAmount);
      });

    it("debería denegar a los usuarios retirar y depositar 0 ETH",
      async function () {
        const { kipubank, user1, user2, user3 } = await networkHelpers.loadFixture(kipuBankFixture);

        // User1 deposits 400 ETH
        const depositAmount1 = ethers.parseEther("0.0004");
        await user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount1 })

        await expect(
          kipubank.connect(user1).withdraw(0)
        ).to.be.revertedWithCustomError(kipubank, "WithdrawalAmountError")
        .withArgs(user1.address, 0);

        await expect(
          user1.sendTransaction({ to: kipubank.getAddress(), value: 0 })
        ).to.be.revertedWithCustomError(kipubank, "ReceiveFallbackDepositError")
        .withArgs(user1.address, 0);
      }
    );
    it("debería denegar a los usuarios retirar más de su saldo",
      async function () {
        const { kipubank, user1, user2, user3 } = await networkHelpers.loadFixture(kipuBankFixture);
        // User1 deposits 0.00005 ETH
        const depositAmount1 = ethers.parseEther("0.00005");

        await expect(() =>
          user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount1 })
        ).to.changeEtherBalances(ethers,[user1, kipubank], [-depositAmount1, depositAmount1]);

        const withdrawAmount = ethers.parseEther("0.0001")
        await expect(
          kipubank.connect(user1).withdraw(withdrawAmount)
        ).to.be.revertedWithCustomError(kipubank, "InsufficientUserBalance")
        .withArgs(withdrawAmount, depositAmount1);
      }
    )
    it("deberia aumentar el contador de Depositos y Retiros al realizar una transacción",
      async function () {
        const { kipubank, user1, user2, user3 } = await networkHelpers.loadFixture(kipuBankFixture);
        // User1 deposits 0.00005 ETH
        const depositAmount1 = ethers.parseEther("0.0001");
        //await user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount1 })
        await kipubank.connect(user1).deposit(depositAmount1,{ value: depositAmount1 })
        const balance = await kipubank.connect(user1).getBalance()
        expect(balance).to.be.equal(depositAmount1);

        const withdrawAmount = ethers.parseEther("0.0001")

        await expect(
          kipubank.connect(user1).withdraw(withdrawAmount)
        ).to.changeEtherBalances(ethers,[user1, kipubank], [withdrawAmount, -withdrawAmount]);

        const depositCount = await kipubank.depositosCount();
        expect(depositCount).to.be.equal(1)
        const withdrawCount = await kipubank.withdrawalCount();
        expect(withdrawCount).to.be.equal(1)
      }
    )
  })
  describe("Eventos", function () {
    it("debería emitir un evento Deposit cuando un usuario deposita ETH",
      async function () {
        const { kipubank, user1 } = await networkHelpers.loadFixture(kipuBankFixture);
        const depositAmount = ethers.parseEther("0.0004");
        await expect(
          user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount })
        ).to.emit(kipubank, "Deposit")
        .withArgs(user1.address, depositAmount, depositAmount)
      }
    )
    it("debería emitir un evento Withdrawal cuando un usuario retira ETH",
      async function () {
        const { kipubank, user1 } = await networkHelpers.loadFixture(kipuBankFixture);
        const depositAmount = ethers.parseEther("0.0004")
        await user1.sendTransaction({ to: kipubank.getAddress(), value: depositAmount })
        const withdrawAmount = ethers.parseEther("0.0001");
        await expect(
          kipubank.connect(user1).withdraw(withdrawAmount))
        .to.emit(kipubank, "Withdrawal")
        .withArgs(user1.address, withdrawAmount, depositAmount - withdrawAmount)
      }
    )
  })
});