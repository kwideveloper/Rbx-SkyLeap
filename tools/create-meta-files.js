#!/usr/bin/env node

/**
 * Script to create files init.meta.json in folders that do not have them
 * This helps prevent red delete files created in Roblox Studio
 */

const fs = require('fs');
const path = require('path');

const META_CONTENT = {
    "ignoreUnknownProperties": true,
    "ignoreUnknownInstances": true
};

function createMetaFiles(dirPath) {
    const items = fs.readdirSync(dirPath);

    for (const item of items) {
        const fullPath = path.join(dirPath, item);
        const stat = fs.statSync(fullPath);

        if (stat.isDirectory()) {
            const metaFilePath = path.join(fullPath, 'init.meta.json');

            // Just create if there is no
            if (!fs.existsSync(metaFilePath)) {
                fs.writeFileSync(metaFilePath, JSON.stringify(META_CONTENT, null, 4));
                console.log(`✅ Creado: ${metaFilePath}`);
            }

            // Recursion in subfolders
            createMetaFiles(fullPath);
        }
    }
}

function main() {
    const srcPath = path.join(__dirname, '..', 'src');

    if (!fs.existsSync(srcPath)) {
        console.error('❌ The SRC folder was not found');
        process.exit(1);
    }

    console.log('🔍 Looking for folders without init.Meta.json in SRC...');
    createMetaFiles(srcPath);
    console.log('✅ ¡Completed process!');
}

if (require.main === module) {
    main();
}

module.exports = { createMetaFiles };
