import * as vscode from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind,
    ErrorAction,
    CloseAction
} from 'vscode-languageclient/node';
import { getExtensionConfig, validateConfig, getServerInitializationOptions, ExtensionConfig } from './config';

let client: LanguageClient | undefined;
let extensionContext: vscode.ExtensionContext | undefined;
let restartCount = 0;

export function activate(context: vscode.ExtensionContext): void {
    console.log('Haskell LSP Extension is being activated');
    extensionContext = context;

    try {
        client = startLanguageServer(context);
        
        // Register commands
        const restartCommand = vscode.commands.registerCommand('haskellLsp.restart', () => {
            restartLanguageServer(context);
        });
        
        // Register configuration change handler
        const configChangeHandler = vscode.workspace.onDidChangeConfiguration(event => {
            if (event.affectsConfiguration('haskellLsp')) {
                handleConfigurationChange(event);
            }
        });
        
        context.subscriptions.push(restartCommand, configChangeHandler);
        
        console.log('Haskell LSP Extension activated successfully');
    } catch (error) {
        console.error('Failed to activate Haskell LSP Extension:', error);
        vscode.window.showErrorMessage(`Failed to start Haskell LSP server: ${error}`);
    }
}

function startLanguageServer(context: vscode.ExtensionContext): LanguageClient {
    const config = getExtensionConfig();
    
    // Validate configuration
    const configErrors = validateConfig(config);
    if (configErrors.length > 0) {
        const errorMessage = `Invalid Haskell LSP configuration:\n${configErrors.join('\n')}`;
        vscode.window.showErrorMessage(errorMessage, 'Open Settings').then(selection => {
            if (selection === 'Open Settings') {
                vscode.commands.executeCommand('workbench.action.openSettings', 'haskellLsp');
            }
        });
        throw new Error(errorMessage);
    }
    
    // Check if server executable exists
    if (!checkServerExecutable(config.serverPath)) {
        const message = `Haskell LSP server executable not found: "${config.serverPath}"`;
        const detailedMessage = `The Haskell LSP server could not be found. Please ensure that:
1. The server is installed and available in your PATH, or
2. Configure the correct path in extension settings

Current configured path: ${config.serverPath}`;
        
        console.error(detailedMessage);
        
        vscode.window.showErrorMessage(
            message,
            'Open Settings',
            'Install Instructions',
            'Browse for Executable'
        ).then(selection => {
            switch (selection) {
                case 'Open Settings':
                    vscode.commands.executeCommand('workbench.action.openSettings', 'haskellLsp.serverPath');
                    break;
                case 'Install Instructions':
                    vscode.env.openExternal(vscode.Uri.parse('https://github.com/haskell/haskell-language-server#installation'));
                    break;
                case 'Browse for Executable':
                    vscode.window.showOpenDialog({
                        canSelectFiles: true,
                        canSelectFolders: false,
                        canSelectMany: false,
                        filters: {
                            'Executables': process.platform === 'win32' ? ['exe'] : ['*']
                        },
                        title: 'Select Haskell LSP Server Executable'
                    }).then(uris => {
                        if (uris && uris.length > 0) {
                            const selectedPath = uris[0].fsPath;
                            const config = vscode.workspace.getConfiguration('haskellLsp');
                            config.update('serverPath', selectedPath, vscode.ConfigurationTarget.Global);
                            vscode.window.showInformationMessage(
                                `Server path updated to: ${selectedPath}. Please reload the window to apply changes.`,
                                'Reload Window'
                            ).then(choice => {
                                if (choice === 'Reload Window') {
                                    vscode.commands.executeCommand('workbench.action.reloadWindow');
                                }
                            });
                        }
                    });
                    break;
            }
        });
        
        throw new Error(message);
    }
    
    // Server options
    const serverOptions: ServerOptions = {
        run: {
            command: config.serverPath,
            args: ['--log-level', config.logLevel],
            transport: TransportKind.stdio
        },
        debug: {
            command: config.serverPath,
            args: ['--log-level', 'debug'],
            transport: TransportKind.stdio
        }
    };
    
    // Client options
    const clientOptions: LanguageClientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'haskell' },
            { scheme: 'untitled', language: 'haskell' }
        ],
        synchronize: {
            fileEvents: [
                vscode.workspace.createFileSystemWatcher('**/*.hs'),
                vscode.workspace.createFileSystemWatcher('**/*.lhs'),
                vscode.workspace.createFileSystemWatcher('**/cabal.project'),
                vscode.workspace.createFileSystemWatcher('**/*.cabal'),
                vscode.workspace.createFileSystemWatcher('**/stack.yaml')
            ],
            configurationSection: 'haskellLsp'
        },
        initializationOptions: getServerInitializationOptions(config),
        errorHandler: {
            error: (error, message, count) => {
                console.error('LSP client error:', error, message, count);
                
                // Show error notification for critical errors
                if (count && count >= 3) {
                    vscode.window.showWarningMessage(
                        `Haskell LSP server encountered ${count} errors. Consider restarting.`,
                        'Restart Server'
                    ).then(selection => {
                        if (selection === 'Restart Server') {
                            restartLanguageServer(context);
                        }
                    });
                }
                
                return { action: ErrorAction.Continue };
            },
            closed: () => {
                console.log('LSP server connection closed');
                
                if (restartCount < config.maxRestartCount) {
                    restartCount++;
                    console.log(`Attempting to restart LSP server (attempt ${restartCount}/${config.maxRestartCount})`);
                    
                    // Show status bar message during restart
                    vscode.window.setStatusBarMessage(
                        `Restarting Haskell LSP server (${restartCount}/${config.maxRestartCount})...`,
                        3000
                    );
                    
                    // Exponential backoff for restart attempts
                    const delay = Math.min(2000 * Math.pow(2, restartCount - 1), 10000);
                    setTimeout(() => {
                        try {
                            restartLanguageServer(context);
                        } catch (error) {
                            console.error('Failed to restart LSP server:', error);
                            vscode.window.showErrorMessage(`Failed to restart Haskell LSP server: ${error}`);
                        }
                    }, delay);
                    
                    return { action: CloseAction.DoNotRestart };
                } else {
                    const message = `Haskell LSP server has crashed ${config.maxRestartCount} times. Please check the server logs and restart manually.`;
                    console.error(message);
                    
                    vscode.window.showErrorMessage(
                        message,
                        'Restart Now',
                        'Open Settings',
                        'View Logs'
                    ).then(selection => {
                        switch (selection) {
                            case 'Restart Now':
                                restartCount = 0;
                                restartLanguageServer(context);
                                break;
                            case 'Open Settings':
                                vscode.commands.executeCommand('workbench.action.openSettings', 'haskellLsp');
                                break;
                            case 'View Logs':
                                vscode.commands.executeCommand('workbench.action.showLogs');
                                break;
                        }
                    });
                    
                    return { action: CloseAction.DoNotRestart };
                }
            }
        }
    };
    
    // Create and start the language client
    const languageClient = new LanguageClient(
        'haskellLsp',
        'Haskell LSP',
        serverOptions,
        clientOptions
    );
    
    // Start the client and server
    languageClient.start().then(() => {
        console.log('Haskell LSP client started successfully');
        restartCount = 0; // Reset restart count on successful start
    }).catch(error => {
        console.error('Failed to start Haskell LSP client:', error);
        throw error;
    });
    
    return languageClient;
}

function checkServerExecutable(serverPath: string): boolean {
    try {
        const { execSync } = require('child_process');
        const { existsSync } = require('fs');
        const path = require('path');
        
        // First check if it's an absolute path and file exists
        if (path.isAbsolute(serverPath)) {
            if (!existsSync(serverPath)) {
                console.log(`Server executable not found at path: ${serverPath}`);
                return false;
            }
        } else {
            // For relative paths or commands, try to execute directly
            // The execSync call below will fail if not found in PATH
        }
        
        // Try to execute the server to verify it works
        execSync(`"${serverPath}" --version`, { 
            stdio: 'ignore', 
            timeout: 5000,
            windowsHide: true 
        });
        
        console.log(`Server executable verified: ${serverPath}`);
        return true;
    } catch (error) {
        console.log(`Server executable check failed for ${serverPath}:`, error);
        return false;
    }
}

function restartLanguageServer(context: vscode.ExtensionContext): void {
    if (client) {
        client.stop().then(() => {
            client = startLanguageServer(context);
        }).catch(error => {
            console.error('Failed to stop language client:', error);
            client = startLanguageServer(context);
        });
    } else {
        client = startLanguageServer(context);
    }
}

function handleConfigurationChange(event: vscode.ConfigurationChangeEvent): void {
    const config = vscode.workspace.getConfiguration('haskellLsp');
    
    console.log('Haskell LSP configuration changed');
    
    // Check if critical settings changed that require restart
    const criticalSettings = ['serverPath'];
    const requiresRestart = criticalSettings.some(setting => 
        event.affectsConfiguration(`haskellLsp.${setting}`)
    );
    
    if (requiresRestart) {
        vscode.window.showInformationMessage(
            'Haskell LSP server configuration changed. Restart required to apply changes.',
            'Restart Now',
            'Restart Later'
        ).then(selection => {
            if (selection === 'Restart Now') {
                restartLanguageServer(extensionContext!);
            }
        });
    } else if (client) {
        // Send configuration update to server for non-critical settings
        const newConfig = getExtensionConfig();
        
        // Send workspace/didChangeConfiguration notification
        client.sendNotification('workspace/didChangeConfiguration', {
            settings: {
                haskellLsp: newConfig
            }
        }).then(() => {
            console.log('Configuration update sent to LSP server');
            vscode.window.setStatusBarMessage('Haskell LSP configuration updated', 2000);
        }).catch(error => {
            console.error('Failed to send configuration update:', error);
        });
    }
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        console.log('No active LSP client to deactivate');
        return undefined;
    }
    
    console.log('Deactivating Haskell LSP Extension');
    
    // Reset restart count
    restartCount = 0;
    
    // Stop the language client and clean up resources
    return client.stop().then(() => {
        console.log('Haskell LSP client stopped successfully');
        client = undefined;
    }).catch(error => {
        console.error('Error stopping Haskell LSP client:', error);
        client = undefined;
        throw error;
    });
}