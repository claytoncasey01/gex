#!/usr/bin/env python3
"""
Realistic Benchmark File Generator for Text Search Tools

This script generates test files with various characteristics that mirror real-world
search scenarios. Understanding these patterns helps us measure performance across
the full spectrum of actual usage rather than artificial edge cases.

The different test scenarios simulate:
- Source code searches (sparse matches, structured content)
- Log file analysis (clustered matches, temporal patterns) 
- Documentation searches (natural language, varied match density)
- Configuration parsing (moderate density, key-value patterns)
"""

import random
import string
import json
import os
from typing import List, Dict, Tuple
from dataclasses import dataclass, asdict

@dataclass
class TestScenario:
    """
    Represents a specific test scenario with defined characteristics.
    
    This structure helps us systematically create different types of content
    that stress different aspects of search algorithm performance.
    """
    name: str
    description: str
    target_lines: int
    match_density: float  # Percentage of lines that should contain matches (0.0 to 1.0)
    search_term: str
    content_type: str
    clustering_factor: float  # 0.0 = evenly distributed, 1.0 = highly clustered
    avg_line_length: int
    line_length_variance: int

class BenchmarkGenerator:
    """
    Generates realistic benchmark files for testing search tool performance.
    
    The generator creates different content types and match patterns to simulate
    the variety of scenarios that users encounter when searching through files
    in real-world applications.
    """
    
    def __init__(self, output_dir: str = "benchmark_files"):
        self.output_dir = output_dir
        self.ensure_output_directory()
        
        # Pre-generate content pools for different types of realistic text
        self.code_keywords = [
            "function", "class", "interface", "import", "export", "const", "let", "var",
            "async", "await", "return", "throw", "catch", "try", "if", "else", "for",
            "while", "switch", "case", "break", "continue", "public", "private", "static"
        ]
        
        self.log_levels = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL", "TRACE"]
        self.log_components = [
            "database", "auth", "cache", "network", "security", "scheduler", "backup",
            "api", "request", "response", "session", "metrics", "performance"
        ]
        
        self.prose_words = [
            "the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her",
            "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "man",
            "new", "now", "old", "see", "two", "way", "who", "boy", "did", "its", "let",
            "put", "say", "she", "too", "use", "data", "system", "process", "function",
            "performance", "optimization", "algorithm", "structure", "implementation"
        ]

    def ensure_output_directory(self) -> None:
        """Create output directory if it doesn't exist."""
        os.makedirs(self.output_dir, exist_ok=True)

    def generate_code_line(self, should_contain_term: bool, search_term: str, target_length: int) -> str:
        """
        Generate a realistic line of code content.
        
        Code content has structured patterns with consistent indentation and syntax.
        This simulates searching through source files where developers look for
        function names, variable declarations, or language constructs.
        """
        indent_level = random.randint(0, 4)
        indent = "    " * indent_level
        
        if should_contain_term:
            # Create realistic code constructs that naturally contain the search term
            patterns = [
                f"function {search_term}Handler(params) {{",
                f"const {search_term} = require('./utils');",
                f"class {search_term.title()}Manager {{",
                f"// Process {search_term} data efficiently",
                f"if ({search_term}.isValid()) {{",
                f"return {search_term}.process(data);",
                f"export {{ {search_term} }} from './module';"
            ]
            base_line = random.choice(patterns)
        else:
            # Generate realistic code without the search term
            keyword = random.choice(self.code_keywords)
            variable = ''.join(random.choices(string.ascii_lowercase, k=random.randint(4, 12)))
            
            patterns = [
                f"{keyword} {variable} = {random.randint(1, 100)};",
                f"if ({variable}.length > 0) {{",
                f"// TODO: implement {variable} validation",
                f"return this.{variable}.map(item => item.id);",
                f"const {variable} = await fetch(apiUrl);",
                f"console.log('Processing {variable}:', data);"
            ]
            base_line = random.choice(patterns)
        
        # Pad or trim to approximate target length
        line = indent + base_line
        if len(line) < target_length:
            # Add realistic code comments or additional statements
            padding = " // " + " ".join(random.choices(self.prose_words, k=random.randint(1, 5)))
            line += padding
        
        return line[:target_length].rstrip()

    def generate_log_line(self, should_contain_term: bool, search_term: str, target_length: int) -> str:
        """
        Generate a realistic log file entry.
        
        Log files have temporal patterns and structured formats. Users often search
        for specific error conditions, timestamps, or component names. The clustering
        factor affects whether matches appear in bursts (like error storms) or 
        distributed evenly.
        """
        timestamp = f"2024-01-{random.randint(10, 30):02d} {random.randint(0, 23):02d}:{random.randint(0, 59):02d}:{random.randint(0, 59):02d}.{random.randint(0, 999):03d}"
        level = random.choice(self.log_levels)
        component = random.choice(self.log_components)
        
        if should_contain_term:
            # Create log messages that naturally contain the search term
            patterns = [
                f"Processing {search_term} request from user",
                f"{search_term.title()} operation completed successfully",
                f"Failed to validate {search_term} parameters",
                f"{search_term.title()} cache hit rate: 87.3%",
                f"Starting {search_term} background job",
                f"{search_term.title()} connection established",
                f"Error in {search_term} handler: timeout occurred"
            ]
            message = random.choice(patterns)
        else:
            # Generate realistic log messages without the search term
            actions = ["started", "completed", "failed", "connecting", "processing", "validating"]
            objects = ["request", "connection", "job", "query", "response", "session"]
            
            action = random.choice(actions)
            obj = random.choice(objects)
            message = f"{action.title()} {obj} for user {random.randint(1000, 9999)}"
        
        # Construct full log line with standard format
        line = f"{timestamp} {level:5} [{component}] {message}"
        
        # Pad to target length if needed
        if len(line) < target_length:
            padding = f" (duration: {random.randint(1, 1000)}ms, memory: {random.randint(10, 500)}MB)"
            line += padding
            
        return line[:target_length].rstrip()

    def generate_prose_line(self, should_contain_term: bool, search_term: str, target_length: int) -> str:
        """
        Generate natural language prose content.
        
        Prose content simulates documentation, README files, or comment blocks.
        These typically have the lowest match density but the most varied sentence
        structures and vocabulary. Performance here tests scanning efficiency through
        natural language patterns.
        """
        if should_contain_term:
            # Create sentences that naturally incorporate the search term
            sentence_templates = [
                f"The {search_term} provides essential functionality for system operations.",
                f"When implementing {search_term}, consider performance implications carefully.",
                f"Understanding {search_term} behavior requires comprehensive analysis of system patterns.",
                f"Modern applications rely heavily on efficient {search_term} implementations.",
                f"Best practices for {search_term} include proper error handling and resource management.",
                f"The {search_term} algorithm demonstrates significant improvements over traditional approaches."
            ]
            sentence = random.choice(sentence_templates)
        else:
            # Generate natural prose without the search term
            sentence_starters = [
                "Modern software development requires",
                "Understanding system architecture involves",
                "Performance optimization techniques include",
                "Database query patterns demonstrate",
                "Effective error handling strategies encompass",
                "Scalable application design principles focus on"
            ]
            
            sentence_endings = [
                "careful consideration of multiple factors and trade-offs.",
                "systematic analysis of performance characteristics and bottlenecks.",
                "comprehensive testing across diverse operational scenarios.",
                "balanced approaches that prioritize both functionality and efficiency.",
                "thorough documentation and clear communication of requirements.",
                "continuous monitoring and iterative improvement processes."
            ]
            
            sentence = random.choice(sentence_starters) + " " + random.choice(sentence_endings)
        
        # Extend sentence to approximate target length
        while len(sentence) < target_length:
            additional_clause = " " + " ".join(random.choices(self.prose_words, k=random.randint(3, 8)))
            sentence += additional_clause
            
        return sentence[:target_length].rstrip()

    def generate_clustered_positions(self, total_lines: int, match_count: int, clustering_factor: float) -> List[int]:
        """
        Generate line positions for matches with specified clustering behavior.
        
        Clustering factor determines whether matches appear in bursts (high clustering)
        or are distributed evenly (low clustering). This simulates realistic patterns
        like error storms in logs or related functions appearing together in code.
        
        clustering_factor: 0.0 = perfectly even distribution, 1.0 = maximum clustering
        """
        positions = []
        
        if clustering_factor < 0.1:
            # Nearly even distribution - good for testing scanning efficiency
            interval = total_lines // match_count
            for i in range(match_count):
                pos = i * interval + random.randint(0, interval // 4)
                positions.append(min(pos, total_lines - 1))
        else:
            # Clustered distribution - simulates realistic log patterns
            cluster_count = max(1, int(match_count * (1 - clustering_factor)))
            matches_per_cluster = match_count // cluster_count
            
            for cluster in range(cluster_count):
                # Choose cluster center randomly
                cluster_center = random.randint(0, total_lines - 1)
                cluster_spread = int(total_lines * clustering_factor * 0.1)
                
                # Generate matches around cluster center
                for _ in range(matches_per_cluster):
                    offset = random.randint(-cluster_spread, cluster_spread)
                    pos = max(0, min(total_lines - 1, cluster_center + offset))
                    positions.append(pos)
            
            # Add remaining matches randomly
            remaining = match_count - len(positions)
            for _ in range(remaining):
                positions.append(random.randint(0, total_lines - 1))
        
        return sorted(set(positions))  # Remove duplicates and sort

    def generate_test_file(self, scenario: TestScenario) -> str:
        """
        Generate a complete test file based on the scenario specifications.
        
        This method orchestrates the creation of realistic content that matches
        the specified characteristics while maintaining the natural patterns
        that users encounter in real files.
        """
        filename = f"{scenario.name.lower().replace(' ', '_')}.txt"
        filepath = os.path.join(self.output_dir, filename)
        
        print(f"Generating {scenario.name} ({scenario.target_lines:,} lines, {scenario.match_density:.1%} match rate)...")
        
        # Calculate how many lines should contain matches
        match_count = int(scenario.target_lines * scenario.match_density)
        match_positions = self.generate_clustered_positions(
            scenario.target_lines, match_count, scenario.clustering_factor
        )
        match_set = set(match_positions)
        
        # Choose content generator based on scenario type
        if scenario.content_type == "code":
            generator = self.generate_code_line
        elif scenario.content_type == "logs":
            generator = self.generate_log_line
        else:  # prose
            generator = self.generate_prose_line
        
        with open(filepath, 'w', encoding='utf-8') as f:
            for line_num in range(scenario.target_lines):
                should_contain_term = line_num in match_set
                
                # Vary line length realistically
                length_variation = random.randint(
                    -scenario.line_length_variance, 
                    scenario.line_length_variance
                )
                target_length = max(10, scenario.avg_line_length + length_variation)
                
                line = generator(should_contain_term, scenario.search_term, target_length)
                f.write(line + '\n')
        
        # Verify actual match count for validation
        actual_matches = 0
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                if scenario.search_term in line:
                    actual_matches += 1
        
        actual_density = actual_matches / scenario.target_lines
        print(f"  Created: {filepath}")
        print(f"  Actual match density: {actual_density:.2%} ({actual_matches:,} matches)")
        
        return filepath

def create_test_scenarios() -> List[TestScenario]:
    """
    Define comprehensive test scenarios that cover realistic usage patterns.
    
    These scenarios are designed to stress different aspects of search performance:
    - Sparse scenarios test scanning efficiency
    - Dense scenarios test output processing efficiency  
    - Clustered scenarios test adaptive performance
    - Mixed scenarios test general robustness
    """
    scenarios = [
        # Sparse matching scenarios - test scanning efficiency
        TestScenario(
            name="sparse_code_search",
            description="Searching for specific function names in large codebase",
            target_lines=100000,
            match_density=0.005,  # 0.5% match rate
            search_term="function",
            content_type="code",
            clustering_factor=0.3,  # Moderate clustering (related functions near each other)
            avg_line_length=60,
            line_length_variance=30
        ),
        
        TestScenario(
            name="rare_error_logs",
            description="Finding rare error conditions in large log files",
            target_lines=200000,
            match_density=0.002,  # 0.2% match rate
            search_term="ERROR",
            content_type="logs",
            clustering_factor=0.8,  # High clustering (errors come in bursts)
            avg_line_length=120,
            line_length_variance=40
        ),
        
        # Moderate matching scenarios - balanced workload
        TestScenario(
            name="moderate_code_search",
            description="Searching for common programming constructs",
            target_lines=75000,
            match_density=0.08,  # 8% match rate
            search_term="function",
            content_type="code",
            clustering_factor=0.4,
            avg_line_length=65,
            line_length_variance=25
        ),
        
        TestScenario(
            name="info_log_analysis",
            description="Analyzing informational log entries",
            target_lines=150000,
            match_density=0.12,  # 12% match rate
            search_term="INFO",
            content_type="logs",
            clustering_factor=0.2,  # More evenly distributed
            avg_line_length=110,
            line_length_variance=50
        ),
        
        # Dense matching scenarios - test output processing
        TestScenario(
            name="dense_prose_search",
            description="Searching for common words in documentation",
            target_lines=50000,
            match_density=0.25,  # 25% match rate
            search_term="system",
            content_type="prose",
            clustering_factor=0.1,  # Nearly even distribution
            avg_line_length=80,
            line_length_variance=20
        ),
        
        # Edge case scenarios
        TestScenario(
            name="very_sparse_large",
            description="Needle in haystack - very rare matches in huge file",
            target_lines=500000,
            match_density=0.0002,  # 0.02% match rate
            search_term="function",
            content_type="code",
            clustering_factor=0.9,  # Highly clustered
            avg_line_length=70,
            line_length_variance=35
        ),
        
        TestScenario(
            name="short_lines_dense",
            description="Dense matches in short-line format (like config files)",
            target_lines=30000,
            match_density=0.15,  # 15% match rate
            search_term="config",
            content_type="code",
            clustering_factor=0.3,
            avg_line_length=25,
            line_length_variance=10
        ),
        
        TestScenario(
            name="long_lines_sparse",
            description="Sparse matches in very long lines",
            target_lines=20000,
            match_density=0.03,  # 3% match rate
            search_term="performance",
            content_type="prose",
            clustering_factor=0.2,
            avg_line_length=200,
            line_length_variance=100
        )
    ]
    
    return scenarios

def main():
    """
    Generate comprehensive benchmark files for realistic performance testing.
    """
    print("=== Realistic Benchmark File Generator ===")
    print("Creating test files that simulate real-world search scenarios...\n")
    
    generator = BenchmarkGenerator()
    scenarios = create_test_scenarios()
    
    # Generate metadata about our test scenarios
    metadata = {
        "generation_timestamp": "2024-01-01T00:00:00Z",  # You might want to use actual timestamp
        "total_scenarios": len(scenarios),
        "scenarios": [asdict(scenario) for scenario in scenarios]
    }
    
    # Save scenario metadata for reference
    metadata_path = os.path.join(generator.output_dir, "scenarios_metadata.json")
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    # Generate all test files
    generated_files = []
    for scenario in scenarios:
        filepath = generator.generate_test_file(scenario)
        generated_files.append(filepath)
        print()  # Add spacing between scenarios
    
    print("=== Generation Complete ===")
    print(f"Generated {len(generated_files)} test files in '{generator.output_dir}/'")
    print(f"Scenario metadata saved to: {metadata_path}")
    print("\nFiles created:")
    for filepath in generated_files:
        file_size = os.path.getsize(filepath) / (1024 * 1024)  # Size in MB
        print(f"  {os.path.basename(filepath):30} ({file_size:.1f} MB)")

if __name__ == "__main__":
    main()
