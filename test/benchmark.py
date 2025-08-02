#!/usr/bin/env python3
"""
Comprehensive Benchmark Runner for Text Search Tools

This script systematically tests search tools against realistic scenarios and captures
detailed performance metrics in structured JSON format. The goal is to understand
exactly where and how much your optimizations improve performance across different
real-world usage patterns.

The script captures multiple types of performance data:
- Execution time (real, user, system)
- Memory usage patterns
- Match count validation
- Statistical reliability through multiple iterations
- Error handling and failure analysis

Results are stored in JSON format for easy analysis, graphing, and comparison
across different optimization attempts.
"""

import subprocess
import json
import time
import os
import sys
import statistics
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
import shlex

@dataclass
class BenchmarkRun:
    """
    Represents a single execution of a search tool with captured metrics.
    
    This structure captures all the important performance characteristics
    that help us understand where optimizations provide benefits and
    identify any performance regressions.
    """
    tool_name: str
    search_term: str
    file_path: str
    real_time: float
    user_time: float
    sys_time: float
    max_memory_kb: Optional[int]
    exit_code: int
    match_count: Optional[int]
    error_message: Optional[str]
    timestamp: str

@dataclass
class BenchmarkSeries:
    """
    Represents multiple runs of the same test for statistical analysis.
    
    Running multiple iterations helps us distinguish between real performance
    differences and random system variation. This is crucial for building
    confidence in optimization results.
    """
    scenario_name: str
    search_term: str
    file_path: str
    iterations: int
    runs: List[BenchmarkRun]
    
    # Statistical summaries
    avg_real_time: Dict[str, float]
    std_real_time: Dict[str, float]
    avg_user_time: Dict[str, float]
    avg_sys_time: Dict[str, float]
    avg_memory_usage: Dict[str, Optional[float]]
    success_rate: Dict[str, float]

class BenchmarkRunner:
    """
    Orchestrates comprehensive performance testing of search tools.
    
    This class handles the complexity of running multiple tools across
    multiple scenarios with proper error handling, statistical analysis,
    and result storage. The goal is to make performance comparison
    scientific and repeatable.
    """
    
    def __init__(self, gex_binary: str = "../zig-out/bin/gex", 
                 ripgrep_binary: str = "rg",
                 iterations: int = 5):
        self.gex_binary = gex_binary
        self.ripgrep_binary = ripgrep_binary
        self.iterations = iterations
        self.results: List[BenchmarkSeries] = []
        
        # Validate that required tools are available
        self.validate_environment()
    
    def validate_environment(self) -> None:
        """
        Ensure that all required tools and dependencies are available.
        
        Early validation prevents frustrating failures halfway through
        a long benchmark run and provides clear error messages about
        what needs to be fixed.
        """
        print("Validating benchmark environment...")
        
        # Check for gex binary
        if not os.path.exists(self.gex_binary):
            raise FileNotFoundError(f"Gex binary not found at: {self.gex_binary}")
        
        if not os.access(self.gex_binary, os.X_OK):
            raise PermissionError(f"Gex binary is not executable: {self.gex_binary}")
        
        # Check for ripgrep
        try:
            result = subprocess.run([self.ripgrep_binary, "--version"], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode != 0:
                raise RuntimeError(f"Ripgrep failed version check: {result.stderr}")
        except FileNotFoundError:
            raise FileNotFoundError(f"Ripgrep not found in PATH: {self.ripgrep_binary}")
        except subprocess.TimeoutExpired:
            raise RuntimeError("Ripgrep version check timed out")
        
        # Check for time command (preferring GNU time for detailed stats)
        self.time_command = self._find_time_command()
        
        print(f"✓ Gex binary: {self.gex_binary}")
        print(f"✓ Ripgrep binary: {self.ripgrep_binary}")
        print(f"✓ Time command: {self.time_command}")
        print()
    
    def _find_time_command(self) -> str:
        """
        Find the best available time command for detailed performance measurement.
        
        GNU time provides more detailed statistics than the shell builtin time.
        We prefer it when available but fall back gracefully to ensure the
        benchmarks can run on different systems.
        """
        # Try GNU time first (provides more detailed memory statistics)
        for time_cmd in ["/usr/bin/time", "gtime", "time"]:
            try:
                result = subprocess.run([time_cmd, "--version"], 
                                      capture_output=True, text=True, timeout=3)
                if result.returncode == 0 and "GNU" in result.stderr:
                    return time_cmd
            except (FileNotFoundError, subprocess.TimeoutExpired):
                continue
        
        # Fallback to basic time command
        return "time"
    
    def run_single_benchmark(self, tool_command: str, tool_name: str, 
                           search_term: str, file_path: str) -> BenchmarkRun:
        """
        Execute a single benchmark run and capture comprehensive metrics.
        
        This method handles the complexity of running the tool, capturing
        timing information, measuring memory usage, and parsing the output
        to extract performance data. Error handling ensures that individual
        test failures don't crash the entire benchmark suite.
        """
        timestamp = datetime.now().isoformat()
        
        try:
            # Construct the full command with timing measurement
            if "GNU" in subprocess.getoutput(f"{self.time_command} --version 2>&1"):
                # GNU time provides detailed memory statistics
                time_format = "-f '%e %U %S %M'"  # real, user, sys, max_memory_kb
                full_command = f"{self.time_command} {time_format} {tool_command}"
            else:
                # Basic time command - less detailed but more portable
                full_command = f"{self.time_command} {tool_command}"
            
            # Execute the command and capture all output
            start_time = time.time()
            process = subprocess.run(
                full_command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30  # Prevent hanging on problematic inputs
            )
            end_time = time.time()
            
            # Parse timing information from stderr (where time outputs its data)
            timing_info = self._parse_timing_output(process.stderr)
            
            # Count actual matches by running the tool again just for output
            match_count = self._count_matches(tool_command)
            
            return BenchmarkRun(
                tool_name=tool_name,
                search_term=search_term,
                file_path=file_path,
                real_time=timing_info.get('real', end_time - start_time),
                user_time=timing_info.get('user', 0.0),
                sys_time=timing_info.get('sys', 0.0),
                max_memory_kb=timing_info.get('memory'),
                exit_code=process.returncode,
                match_count=match_count,
                error_message=process.stderr if process.returncode != 0 else None,
                timestamp=timestamp
            )
            
        except subprocess.TimeoutExpired:
            return BenchmarkRun(
                tool_name=tool_name,
                search_term=search_term,
                file_path=file_path,
                real_time=30.0,  # Timeout duration
                user_time=0.0,
                sys_time=0.0,
                max_memory_kb=None,
                exit_code=-1,
                match_count=None,
                error_message="Timeout after 30 seconds",
                timestamp=timestamp
            )
        except Exception as e:
            return BenchmarkRun(
                tool_name=tool_name,
                search_term=search_term,
                file_path=file_path,
                real_time=0.0,
                user_time=0.0,
                sys_time=0.0,
                max_memory_kb=None,
                exit_code=-1,
                match_count=None,
                error_message=str(e),
                timestamp=timestamp
            )
    
    def _parse_timing_output(self, stderr_output: str) -> Dict[str, float]:
        """
        Parse timing information from the time command output.
        
        Different versions of the time command format their output differently.
        This method handles the variations and extracts the key metrics we need
        for performance analysis.
        """
        timing_info = {}
        
        # Try to parse GNU time format first
        lines = stderr_output.strip().split('\n')
        for line in lines:
            # GNU time format: "real user sys memory"
            if line and not line.startswith('Command') and ' ' in line:
                parts = line.split()
                if len(parts) >= 4:
                    try:
                        timing_info['real'] = float(parts[0])
                        timing_info['user'] = float(parts[1])
                        timing_info['sys'] = float(parts[2])
                        timing_info['memory'] = int(parts[3])
                        return timing_info
                    except (ValueError, IndexError):
                        continue
            
            # Standard time format parsing
            if 'real' in line:
                try:
                    time_part = line.split()[1] if len(line.split()) > 1 else line.split()[0]
                    # Handle formats like "0m1.234s"
                    if 'm' in time_part and 's' in time_part:
                        minutes, seconds = time_part.replace('s', '').split('m')
                        timing_info['real'] = float(minutes) * 60 + float(seconds)
                    else:
                        timing_info['real'] = float(time_part.replace('s', ''))
                except (ValueError, IndexError):
                    pass
            
            elif 'user' in line:
                try:
                    time_part = line.split()[1] if len(line.split()) > 1 else line.split()[0]
                    if 'm' in time_part and 's' in time_part:
                        minutes, seconds = time_part.replace('s', '').split('m')
                        timing_info['user'] = float(minutes) * 60 + float(seconds)
                    else:
                        timing_info['user'] = float(time_part.replace('s', ''))
                except (ValueError, IndexError):
                    pass
            
            elif 'sys' in line:
                try:
                    time_part = line.split()[1] if len(line.split()) > 1 else line.split()[0]
                    if 'm' in time_part and 's' in time_part:
                        minutes, seconds = time_part.replace('s', '').split('m')
                        timing_info['sys'] = float(minutes) * 60 + float(seconds)
                    else:
                        timing_info['sys'] = float(time_part.replace('s', ''))
                except (ValueError, IndexError):
                    pass
        
        return timing_info
    
    def _count_matches(self, tool_command: str) -> Optional[int]:
        """
        Count the actual number of matches found by running the tool.
        
        This validation step ensures that both tools are finding the same
        matches and helps identify any correctness issues. Performance
        comparisons are only meaningful when both tools produce equivalent
        results.
        """
        try:
            result = subprocess.run(
                tool_command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                # Count non-empty lines in output
                lines = [line for line in result.stdout.split('\n') if line.strip()]
                return len(lines)
            else:
                return 0  # No matches found
                
        except Exception:
            return None  # Could not determine match count
    
    def run_benchmark_series(self, scenario_file: str, search_term: str, 
                           scenario_name: str) -> BenchmarkSeries:
        """
        Run a complete benchmark series comparing both tools across multiple iterations.
        
        This method orchestrates the comparison between gex and ripgrep for a specific
        scenario, ensuring statistical reliability through multiple runs and providing
        comprehensive analysis of the results.
        """
        print(f"\n=== Running {scenario_name} ===")
        print(f"File: {scenario_file}")
        print(f"Search term: '{search_term}'")
        print(f"Iterations: {self.iterations}")
        
        # Validate that the test file exists
        if not os.path.exists(scenario_file):
            raise FileNotFoundError(f"Scenario file not found: {scenario_file}")
        
        # Get file size for context
        file_size = os.path.getsize(scenario_file) / (1024 * 1024)  # MB
        print(f"File size: {file_size:.1f} MB")
        
        all_runs = []
        
        # Run multiple iterations for statistical reliability
        for iteration in range(1, self.iterations + 1):
            print(f"  Iteration {iteration}/{self.iterations}:", end=" ", flush=True)
            
            # Test Gex
            gex_command = f"{shlex.quote(self.gex_binary)} {shlex.quote(search_term)} {shlex.quote(scenario_file)}"
            gex_run = self.run_single_benchmark(gex_command, "gex", search_term, scenario_file)
            all_runs.append(gex_run)
            
            # Test Ripgrep
            rg_command = f"{shlex.quote(self.ripgrep_binary)} {shlex.quote(search_term)} {shlex.quote(scenario_file)}"
            rg_run = self.run_single_benchmark(rg_command, "ripgrep", search_term, scenario_file)
            all_runs.append(rg_run)
            
            print(f"Gex: {gex_run.real_time:.3f}s, RG: {rg_run.real_time:.3f}s")
        
        # Calculate statistical summaries
        gex_runs = [run for run in all_runs if run.tool_name == "gex"]
        rg_runs = [run for run in all_runs if run.tool_name == "ripgrep"]
        
        summary = BenchmarkSeries(
            scenario_name=scenario_name,
            search_term=search_term,
            file_path=scenario_file,
            iterations=self.iterations,
            runs=all_runs,
            avg_real_time=self._calculate_averages(gex_runs, rg_runs, 'real_time'),
            std_real_time=self._calculate_std_devs(gex_runs, rg_runs, 'real_time'),
            avg_user_time=self._calculate_averages(gex_runs, rg_runs, 'user_time'),
            avg_sys_time=self._calculate_averages(gex_runs, rg_runs, 'sys_time'),
            avg_memory_usage=self._calculate_memory_averages(gex_runs, rg_runs),
            success_rate=self._calculate_success_rates(gex_runs, rg_runs)
        )
        
        # Display summary statistics
        self._print_summary(summary)
        
        return summary
    
    def _calculate_averages(self, gex_runs: List[BenchmarkRun], 
                          rg_runs: List[BenchmarkRun], 
                          field: str) -> Dict[str, float]:
        """Calculate average values for a specific metric across successful runs."""
        gex_values = [getattr(run, field) for run in gex_runs if run.exit_code == 0]
        rg_values = [getattr(run, field) for run in rg_runs if run.exit_code == 0]
        
        return {
            "gex": statistics.mean(gex_values) if gex_values else 0.0,
            "ripgrep": statistics.mean(rg_values) if rg_values else 0.0
        }
    
    def _calculate_std_devs(self, gex_runs: List[BenchmarkRun], 
                          rg_runs: List[BenchmarkRun], 
                          field: str) -> Dict[str, float]:
        """Calculate standard deviations for statistical reliability assessment."""
        gex_values = [getattr(run, field) for run in gex_runs if run.exit_code == 0]
        rg_values = [getattr(run, field) for run in rg_runs if run.exit_code == 0]
        
        return {
            "gex": statistics.stdev(gex_values) if len(gex_values) > 1 else 0.0,
            "ripgrep": statistics.stdev(rg_values) if len(rg_values) > 1 else 0.0
        }
    
    def _calculate_memory_averages(self, gex_runs: List[BenchmarkRun], 
                                 rg_runs: List[BenchmarkRun]) -> Dict[str, Optional[float]]:
        """Calculate average memory usage when available."""
        gex_memory = [run.max_memory_kb for run in gex_runs if run.max_memory_kb is not None]
        rg_memory = [run.max_memory_kb for run in rg_runs if run.max_memory_kb is not None]
        
        return {
            "gex": statistics.mean(gex_memory) if gex_memory else None,
            "ripgrep": statistics.mean(rg_memory) if rg_memory else None
        }
    
    def _calculate_success_rates(self, gex_runs: List[BenchmarkRun], 
                               rg_runs: List[BenchmarkRun]) -> Dict[str, float]:
        """Calculate success rates for reliability assessment."""
        return {
            "gex": sum(1 for run in gex_runs if run.exit_code == 0) / len(gex_runs),
            "ripgrep": sum(1 for run in rg_runs if run.exit_code == 0) / len(rg_runs)
        }
    
    def _print_summary(self, summary: BenchmarkSeries) -> None:
        """Display a readable summary of benchmark results."""
        print("\n--- Summary ---")
        
        gex_time = summary.avg_real_time["gex"]
        rg_time = summary.avg_real_time["ripgrep"]
        
        if rg_time > 0:
            improvement = ((rg_time - gex_time) / rg_time) * 100
            print(f"Average real time - Gex: {gex_time:.3f}s, Ripgrep: {rg_time:.3f}s")
            if improvement > 0:
                print(f"🚀 Gex is {improvement:.1f}% faster than ripgrep")
            else:
                print(f"📊 Ripgrep is {-improvement:.1f}% faster than Gex")
        
        # Memory comparison if available
        gex_mem = summary.avg_memory_usage.get("gex")
        rg_mem = summary.avg_memory_usage.get("ripgrep")
        if gex_mem and rg_mem:
            mem_improvement = ((rg_mem - gex_mem) / rg_mem) * 100
            print(f"Average memory - Gex: {gex_mem:.0f}KB, Ripgrep: {rg_mem:.0f}KB")
            if mem_improvement > 0:
                print(f"💾 Gex uses {mem_improvement:.1f}% less memory")
    
    def save_results(self, output_file: str) -> None:
        """
        Save comprehensive benchmark results to JSON format.
        
        The JSON format makes it easy to analyze results programmatically,
        create visualizations, or compare results across different optimization
        attempts. The structured format preserves all the detailed information
        needed for thorough performance analysis.
        """
        results_data = {
            "benchmark_metadata": {
                "timestamp": datetime.now().isoformat(),
                "gex_binary": self.gex_binary,
                "ripgrep_binary": self.ripgrep_binary,
                "iterations_per_test": self.iterations,
                "total_scenarios": len(self.results)
            },
            "benchmark_series": [asdict(series) for series in self.results]
        }
        
        with open(output_file, 'w') as f:
            json.dump(results_data, f, indent=2, default=str)
        
        print(f"\n📊 Results saved to: {output_file}")

def load_scenarios_metadata(benchmark_dir: str = "benchmark_files") -> List[Dict]:
    """
    Load scenario metadata to understand what test files are available.
    
    This function reads the metadata generated by the file creation script
    to automatically discover available test scenarios and their characteristics.
    """
    metadata_file = os.path.join(benchmark_dir, "scenarios_metadata.json")
    
    if not os.path.exists(metadata_file):
        raise FileNotFoundError(f"Scenarios metadata not found: {metadata_file}")
    
    with open(metadata_file, 'r') as f:
        metadata = json.load(f)
    
    return metadata["scenarios"]

def main():
    """
    Main execution function that orchestrates comprehensive performance testing.
    """
    print("=== Comprehensive Gex vs Ripgrep Benchmark Runner ===")
    print("Running systematic performance tests across realistic scenarios...\n")
    
    # Configuration
    benchmark_dir = "benchmark_files"
    output_file = f"benchmark_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    
    # Initialize benchmark runner
    runner = BenchmarkRunner(iterations=5)  # 5 iterations for statistical reliability
    
    try:
        # Load available test scenarios
        scenarios = load_scenarios_metadata(benchmark_dir)
        print(f"Found {len(scenarios)} test scenarios")
        
        # Run benchmarks for each scenario
        for scenario in scenarios:
            scenario_file = os.path.join(benchmark_dir, f"{scenario['name']}.txt")
            
            if os.path.exists(scenario_file):
                try:
                    series = runner.run_benchmark_series(
                        scenario_file, 
                        scenario['search_term'], 
                        scenario['name']
                    )
                    runner.results.append(series)
                except Exception as e:
                    print(f"❌ Failed to run scenario {scenario['name']}: {e}")
                    continue
            else:
                print(f"⚠️ Scenario file not found: {scenario_file}")
        
        # Save comprehensive results
        runner.save_results(output_file)
        
        # Print overall summary
        print("\n=== Overall Results Summary ===")
        total_improvements = 0
        total_tests = 0
        
        for series in runner.results:
            gex_time = series.avg_real_time["gex"]
            rg_time = series.avg_real_time["ripgrep"]
            
            if rg_time > 0:
                improvement = ((rg_time - gex_time) / rg_time) * 100
                total_improvements += improvement
                total_tests += 1
                
                status = "🚀" if improvement > 0 else "📊"
                print(f"{status} {series.scenario_name}: {improvement:+.1f}%")
        
        if total_tests > 0:
            avg_improvement = total_improvements / total_tests
            print(f"\n📈 Average performance improvement: {avg_improvement:+.1f}%")
            
            if avg_improvement > 0:
                print("🎉 Gex is faster than ripgrep on average!")
            else:
                print("📊 Room for improvement - ripgrep is currently faster on average")
    
    except KeyboardInterrupt:
        print("\n⏹️ Benchmark interrupted by user")
        if runner.results:
            runner.save_results(f"partial_{output_file}")
            print("Partial results saved.")
    except Exception as e:
        print(f"\n❌ Benchmark failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
