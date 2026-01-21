import { PriceKeeper } from './services/PriceKeeper';
import { Liquidator } from './services/Liquidator';
import { FundingKeeper } from './services/FundingKeeper';
import { VIPKeeper } from './services/VIPKeeper';
import { EXCHANGE_ADDRESS } from './config';

async function main() {
    console.log('--- Monad Exchange Keeper Service ---');

    const priceKeeper = new PriceKeeper(1000); // Update every 1 second
    const liquidator = new Liquidator(5000);   // Check every 5 seconds
    const fundingKeeper = new FundingKeeper(60000); // Check every 60 seconds
    const vipKeeper = new VIPKeeper(EXCHANGE_ADDRESS, 3600000); // Check every 1 hour

    priceKeeper.start();
    await liquidator.start();
    fundingKeeper.start();
    vipKeeper.start();

    // Handle shutdown
    process.on('SIGINT', () => {
        console.log('\nShutting down...');
        priceKeeper.stop();
        liquidator.stop();
        fundingKeeper.stop();
        vipKeeper.stop();
        process.exit(0);
    });
}

main().catch(console.error);
