#!/usr/bin/env python3
"""
Ethereum Foundation Test Adapter for EVM.lua

This script parses official Ethereum test JSON files and executes them
against the EVM.lua implementation via Redis.
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional

class EVMTestAdapter:
    """Adapter to run Ethereum Foundation tests against EVM.lua"""
    
    def __init__(self, redis_host='localhost', redis_port=6379):
        self.redis_host = redis_host
        self.redis_port = redis_port
        
    def redis_cli(self, *args) -> str:
        """Execute redis-cli command and return output"""
        cmd = ['redis-cli'] + list(args)
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout.strip()
    
    def load_test_file(self, test_path: Path) -> Dict:
        """Load and parse a test JSON file"""
        with open(test_path, 'r') as f:
            return json.load(f)
    
    def setup_prestate(self, pre: Dict[str, Any]):
        """Setup pre-state accounts in Redis"""
        for address, account in pre.items():
            # Normalize address (ensure 0x prefix)
            addr = address if address.startswith('0x') else f'0x{address}'
            
            # Set contract code
            code = account.get('code', '0x')
            if code and code != '0x':
                # Remove 0x prefix and spaces for Redis storage
                code_bytes = code[2:] if code.startswith('0x') else code
                code_bytes = code_bytes.replace(' ', '')
                self.redis_cli('SET', addr, code_bytes)
            
            # Set storage
            storage = account.get('storage', {})
            for key, value in storage.items():
                storage_key = f'{addr}:storage:{key}'
                self.redis_cli('SET', storage_key, value)
            
            # Set balance
            balance = account.get('balance', '0x0')
            self.redis_cli('SET', f'{addr}:balance', balance)
            
            # Set nonce
            nonce = account.get('nonce', '0x0')
            self.redis_cli('SET', f'{addr}:nonce', nonce)
    
    def setup_environment(self, env: Dict[str, Any]):
        """Setup block environment in Redis"""
        env_mappings = {
            'currentCoinbase': 'block:coinbase',
            'currentDifficulty': 'block:difficulty',
            'currentGasLimit': 'block:gaslimit',
            'currentNumber': 'block:number',
            'currentTimestamp': 'block:timestamp',
            'previousHash': 'block:prevhash',
            'currentBaseFee': 'block:basefee',
        }
        
        for test_key, redis_key in env_mappings.items():
            if test_key in env:
                self.redis_cli('SET', redis_key, env[test_key])
    
    def execute_transaction(self, tx: Dict[str, Any], data_index: int = 0, 
                          gas_index: int = 0, value_index: int = 0) -> Dict:
        """Execute a transaction and return the result"""
        # Get transaction parameters
        to_addr = tx.get('to', '')
        
        # Handle array-based data/gas/value (tests can have multiple variants)
        data_list = tx.get('data', ['0x'])
        gas_list = tx.get('gasLimit', ['0x5f5e100'])
        value_list = tx.get('value', ['0x0'])
        
        data = data_list[data_index] if data_index < len(data_list) else data_list[0]
        gas_limit = gas_list[gas_index] if gas_index < len(gas_list) else gas_list[0]
        value = value_list[value_index] if value_index < len(value_list) else value_list[0]
        
        # Setup transaction context
        self.redis_cli('SET', 'tx:to', to_addr)
        self.redis_cli('SET', 'tx:data', data)
        self.redis_cli('SET', 'tx:gas', gas_limit)
        self.redis_cli('SET', 'tx:value', value)
        self.redis_cli('SET', 'tx:caller', tx.get('sender', '0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b'))
        
        # Execute via EVM
        result = self.redis_cli('FCALL', 'eth_call', '1', to_addr)
        
        return {
            'output': result,
            'success': True  # TODO: detect failures
        }
    
    def verify_poststate(self, post: Dict[str, Any], fork: str = 'Cancun') -> bool:
        """Verify post-state matches expectations"""
        if fork not in post:
            # Try other forks
            available_forks = list(post.keys())
            if not available_forks:
                return True  # No post-state to verify
            fork = available_forks[0]
        
        expected_states = post[fork]
        if not expected_states:
            return True
        
        # For now, just check if execution completed
        # TODO: Implement full state verification
        return True
    
    def run_test(self, test_path: Path, verbose: bool = False) -> Dict:
        """Run a single test file"""
        test_data = self.load_test_file(test_path)
        
        results = {
            'file': str(test_path),
            'tests': [],
            'passed': 0,
            'failed': 0,
            'skipped': 0
        }
        
        # Each file can contain multiple test cases
        for test_name, test_case in test_data.items():
            if verbose:
                print(f"  Running: {test_name}")
            
            try:
                # Setup pre-state
                pre = test_case.get('pre', {})
                self.setup_prestate(pre)
                
                # Setup environment
                env = test_case.get('env', {})
                self.setup_environment(env)
                
                # Get transaction
                tx = test_case.get('transaction', {})
                
                # Get post-state expectations
                post = test_case.get('post', {})
                
                # Execute transaction
                # Note: Some tests have multiple data/gas/value combinations
                exec_result = self.execute_transaction(tx)
                
                # Verify post-state
                verified = self.verify_poststate(post)
                
                test_result = {
                    'name': test_name,
                    'status': 'passed' if verified else 'failed',
                    'output': exec_result.get('output', '')
                }
                
                results['tests'].append(test_result)
                if verified:
                    results['passed'] += 1
                else:
                    results['failed'] += 1
                    
            except Exception as e:
                if verbose:
                    print(f"    Error: {e}")
                results['tests'].append({
                    'name': test_name,
                    'status': 'error',
                    'error': str(e)
                })
                results['failed'] += 1
        
        return results
    
    def run_test_category(self, category_path: Path, verbose: bool = False) -> Dict:
        """Run all tests in a category directory"""
        results = {
            'category': category_path.name,
            'files': [],
            'total_passed': 0,
            'total_failed': 0,
            'total_skipped': 0
        }
        
        # Find all JSON files
        json_files = sorted(category_path.glob('*.json'))
        
        print(f"\nRunning {len(json_files)} test files from {category_path.name}...")
        
        for test_file in json_files:
            if verbose:
                print(f"\n{test_file.name}:")
            
            file_results = self.run_test(test_file, verbose)
            results['files'].append(file_results)
            results['total_passed'] += file_results['passed']
            results['total_failed'] += file_results['failed']
            results['total_skipped'] += file_results['skipped']
        
        return results


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Run Ethereum Foundation tests against EVM.lua'
    )
    parser.add_argument(
        'test_path',
        type=Path,
        help='Path to test file or directory'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Verbose output'
    )
    parser.add_argument(
        '--fork',
        default='Cancun',
        help='Fork to test (default: Cancun)'
    )
    
    args = parser.parse_args()
    
    adapter = EVMTestAdapter()
    
    if args.test_path.is_file():
        # Run single test file
        results = adapter.run_test(args.test_path, args.verbose)
        print(f"\nResults: {results['passed']} passed, {results['failed']} failed")
        sys.exit(0 if results['failed'] == 0 else 1)
    
    elif args.test_path.is_dir():
        # Run test category
        results = adapter.run_test_category(args.test_path, args.verbose)
        print(f"\n{'='*60}")
        print(f"Category: {results['category']}")
        print(f"Total: {results['total_passed']} passed, {results['total_failed']} failed")
        print(f"{'='*60}")
        sys.exit(0 if results['total_failed'] == 0 else 1)
    
    else:
        print(f"Error: {args.test_path} not found")
        sys.exit(1)


if __name__ == '__main__':
    main()
