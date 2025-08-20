"""
Pydantic models generated from Pulumi Nonsense Provider schema
Demonstrates how to convert Pulumi schema definitions to Python types
"""

from typing import Dict, List, Optional, Union, Any
from pydantic import BaseModel, Field, validator, root_validator
from enum import Enum
import re
from datetime import datetime


class NonsenseLevel(str, Enum):
    """Enumeration for nonsense levels"""
    LOW = "low"
    MEDIUM = "medium" 
    HIGH = "high"
    MAXIMUM = "maximum"


class QuantumState(str, Enum):
    """Quantum superposition states"""
    SUPERPOSITION = "superposition"
    ENTANGLED = "entangled"
    OBSERVED = "observed"
    DECOHERENT = "decoherent"


class EnchantmentType(str, Enum):
    """Types of magical enchantments"""
    FIRE = "fire"
    ICE = "ice"
    LIGHTNING = "lightning"
    CONFUSION = "confusion"
    TIME_WARP = "time-warp"
    REALITY_BENDING = "reality-bending"


class ParadoxType(str, Enum):
    """Types of temporal paradoxes"""
    GRANDFATHER = "grandfather"
    BOOTSTRAP = "bootstrap"
    PREDESTINATION = "predestination"
    CAUSAL_LOOP = "causal-loop"
    TEMPORAL_DISPLACEMENT = "temporal-displacement"
    BUTTERFLY_EFFECT = "butterfly-effect"


class UniversalConstants(BaseModel):
    """Override universal constants for provider instance"""
    speed_of_light: float = Field(default=299792458, description="Speed of light in provider units per second")
    plancks_constant: float = Field(default=6.62607015e-34, description="Planck's constant in provider units")
    answer_to_everything: int = Field(default=42, ge=1, le=100, description="The answer to life, the universe, and everything")


class MagicalReagents(BaseModel):
    """Required magical reagents and quantities"""
    dragon_scale: Optional[int] = Field(default=0, ge=0, le=999, description="Number of dragon scales required")
    unicorn_hair: Optional[int] = Field(default=0, ge=0, le=100, description="Strands of unicorn hair needed")
    pixie_dust: Optional[float] = Field(default=0.0, ge=0.0, le=50.0, multiple_of=0.1, description="Grams of pixie dust")
    
    class Config:
        extra = "allow"  # Allow additional reagents


class MagicalProperties(BaseModel):
    """Comprehensive magical properties with validation constraints"""
    spell_power: int = Field(ge=1, le=100, default=50, description="Magical spell power level")
    enchantment_type: EnchantmentType = Field(description="Type of enchantment applied")
    runic_inscriptions: List[str] = Field(min_items=1, max_items=12, description="Runic inscriptions in ancient format")
    magical_reagents: Optional[MagicalReagents] = Field(default=None, description="Required magical reagents")
    mana_capacity: Optional[float] = Field(default=None, ge=0.0, lt=10000.0, description="Maximum mana capacity")
    is_blessed: bool = Field(default=False, description="Whether properties have divine blessing")
    
    @validator('runic_inscriptions')
    def validate_runic_format(cls, v):
        """Validate runic inscription format"""
        pattern = re.compile(r'^[A-Z]{3,10}$')
        for inscription in v:
            if not pattern.match(inscription):
                raise ValueError(f"Runic inscription '{inscription}' must be 3-10 uppercase letters")
        if len(v) != len(set(v)):
            raise ValueError("Runic inscriptions must be unique")
        return v


class UncertaintyPrinciple(BaseModel):
    """Heisenberg uncertainty principle measurements"""
    position_uncertainty: float = Field(ge=0.0, description="Position measurement uncertainty")
    momentum_uncertainty: float = Field(ge=0.0, description="Momentum measurement uncertainty")
    
    @root_validator
    def validate_uncertainty_product(cls, values):
        """Validate that uncertainty product satisfies Heisenberg principle"""
        pos = values.get('position_uncertainty', 0)
        mom = values.get('momentum_uncertainty', 0)
        hbar_over_2 = 5.272859e-35  # ℏ/2 in SI units
        if pos * mom < hbar_over_2:
            raise ValueError(f"Uncertainty product {pos * mom} violates Heisenberg principle (must be >= {hbar_over_2})")
        return values


class QuantumProperties(BaseModel):
    """Quantum mechanical properties with scientific validation"""
    wave_function: str = Field(description="Quantum wave function equation", min_length=10, max_length=500)
    observer_effect: bool = Field(description="Whether quantum observer effect is active")
    entangled_with: List[str] = Field(default=[], max_items=10, description="URNs of entangled resources")
    probability_cloud: Dict[str, float] = Field(default={}, description="Quantum probability distribution")
    uncertainty_principle: Optional[UncertaintyPrinciple] = Field(default=None)
    coherence_time: Optional[float] = Field(default=None, gt=0.0, le=1000000.0, description="Quantum coherence time in ns")
    
    @validator('wave_function')
    def validate_wave_function_format(cls, v):
        """Validate wave function equation format"""
        pattern = re.compile(r'^ψ\([a-z,t]+\)\s*=.*$')
        if not pattern.match(v):
            raise ValueError("Wave function must match format 'ψ(x,t) = ...'")
        return v
    
    @validator('entangled_with')
    def validate_urns(cls, v):
        """Validate Pulumi URN format"""
        urn_pattern = re.compile(r'^urn:pulumi:.*::.*\$.*::.*$')
        for urn in v:
            if not urn_pattern.match(urn):
                raise ValueError(f"Invalid URN format: {urn}")
        return v
    
    @validator('probability_cloud')
    def validate_probability_values(cls, v):
        """Validate probability values are between 0 and 1"""
        for state, prob in v.items():
            if not (0.0 <= prob <= 1.0):
                raise ValueError(f"Probability for state '{state}' must be between 0.0 and 1.0")
            if not re.match(r'^state_[a-z0-9_]+$', state):
                raise ValueError(f"State key '{state}' must match pattern 'state_[a-z0-9_]+'")
        return v


class TemporalCoordinates(BaseModel):
    """Space-time coordinates with validation"""
    timestamp: datetime = Field(description="ISO 8601 timestamp with precision")
    dimensional_coordinates: List[float] = Field(min_items=3, max_items=11, description="Multi-dimensional coordinates")
    timeline_id: str = Field(description="Unique timeline identifier")
    paradox_risk: str = Field(description="Risk level of temporal paradoxes")
    
    @validator('timeline_id')
    def validate_timeline_format(cls, v):
        """Validate timeline ID format"""
        pattern = re.compile(r'^timeline-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$')
        if not pattern.match(v):
            raise ValueError("Timeline ID must match UUID format with 'timeline-' prefix")
        return v


class MagicalUnicornInput(BaseModel):
    """Input properties for MagicalUnicorn resource"""
    name: str = Field(min_length=3, max_length=50, description="Unicorn's mystical name")
    horn_length: float = Field(ge=0.1, le=10.0, multiple_of=0.1, description="Horn length in magical units")
    rainbow_intensity: int = Field(default=50, ge=1, le=100, description="Rainbow generation intensity")
    magical_properties: Optional[MagicalProperties] = Field(default=None)
    preferred_habitat: str = Field(default="enchanted_forest", description="Preferred natural habitat")
    
    @validator('name')
    def validate_name_format(cls, v):
        """Validate unicorn name format"""
        pattern = re.compile(r'^[A-Z][a-zA-Z\'\-\s]{2,49}$')
        if not pattern.match(v):
            raise ValueError("Name must start with capital letter and contain only letters, spaces, hyphens, apostrophes")
        return v


class SchrodingersResourceInput(BaseModel):
    """Input properties for SchrodingersResource"""
    name: str = Field(description="Quantum resource name")
    initial_state: str = Field(default="superposition", description="Initial quantum state")
    quantum_properties: Optional[QuantumProperties] = Field(default=None)
    half_life: float = Field(default=42.0, ge=0.001, le=1000000.0, description="Quantum decay half-life")
    isolation_level: str = Field(default="standard", description="Quantum isolation level")
    
    @validator('name')
    def validate_quantum_name(cls, v):
        """Validate quantum resource name format"""
        pattern = re.compile(r'^quantum-[a-z0-9\-]{3,30}$')
        if not pattern.match(v):
            raise ValueError("Quantum name must match pattern 'quantum-[a-z0-9-]{3,30}'")
        return v


class TimeParadoxInput(BaseModel):
    """Input properties for TimeParadox resource"""
    name: str = Field(description="Name of the time paradox")
    paradox_type: ParadoxType = Field(description="Type of temporal paradox")
    target_timestamp: datetime = Field(description="Target timestamp for paradox")
    severity_level: int = Field(default=5, ge=1, le=10, description="Paradox severity level")
    
    @validator('name')
    def validate_paradox_name(cls, v):
        """Validate paradox name format"""
        pattern = re.compile(r'^[A-Z][a-zA-Z0-9\s\-]{4,49}$')
        if not pattern.match(v):
            raise ValueError("Paradox name must be 5-50 characters, start with capital")
        return v


class GenerateNonsenseInput(BaseModel):
    """Input for generateNonsense function"""
    length: int = Field(default=100, ge=10, le=10000, description="Target length of nonsense")
    style: str = Field(default="jabberwocky", description="Literary style")
    include_emojis: bool = Field(default=False, description="Include Unicode emojis")
    complexity_level: float = Field(default=0.5, ge=0.0, le=1.0, description="Linguistic complexity")
    seed_value: Optional[int] = Field(default=None, ge=0, le=2147483647, description="Random seed")


class LinguisticAnalysis(BaseModel):
    """Analysis of generated nonsense text"""
    average_word_length: float = Field(description="Average word length")
    syllable_complexity: float = Field(description="Syllable complexity score")
    readability_score: float = Field(description="Readability index")
    contains_real_words: bool = Field(description="Whether text contains real words")


class GenerateNonsenseOutput(BaseModel):
    """Output from generateNonsense function"""
    text: str = Field(description="Generated nonsensical text")
    word_count: int = Field(description="Actual word count")
    nonsense_rating: float = Field(ge=0.0, le=10.0, description="Scientific nonsense rating")
    linguistic_analysis: Optional[LinguisticAnalysis] = Field(default=None)


class ValidateQuantumStateInput(BaseModel):
    """Input for validateQuantumState function"""
    wave_function: str = Field(description="Quantum wave function to validate")
    observer_present: bool = Field(default=False, description="Conscious observer present")
    measurement_type: str = Field(description="Type of quantum measurement")
    temperature: Optional[float] = Field(default=None, ge=0.0, le=1000000.0, description="Temperature in Kelvin")
    isolation_quality: float = Field(default=0.9, ge=0.0, le=1.0, description="Quantum isolation quality")
    
    @validator('wave_function')
    def validate_wave_function(cls, v):
        """Validate wave function format"""
        pattern = re.compile(r'^ψ\([a-z,t]+\)\s*=.*$')
        if not pattern.match(v):
            raise ValueError("Wave function must match format 'ψ(variables) = equation'")
        return v


class ValidateQuantumStateOutput(BaseModel):
    """Output from validateQuantumState function"""
    is_valid: bool = Field(description="Whether quantum state is valid")
    probability: float = Field(ge=0.0, le=1.0, description="Measurement probability")
    collapsed: bool = Field(description="Wave function collapsed")
    uncertainty_principle: UncertaintyPrinciple = Field(description="Uncertainty calculations")
    validation_errors: List[str] = Field(default=[], description="Validation error messages")


# Provider configuration model
class NonsenseProviderConfig(BaseModel):
    """Configuration for the Nonsense provider"""
    nonsense_level: NonsenseLevel = Field(default=NonsenseLevel.MEDIUM, description="Provider nonsense level")
    enable_chaos: bool = Field(default=False, description="Enable chaotic behavior")
    quantum_state: QuantumState = Field(default=QuantumState.SUPERPOSITION, description="Default quantum state")
    temporal_stability_factor: float = Field(default=0.8, ge=0.0, le=1.0, description="Temporal stability factor")
    universal_constants: Optional[UniversalConstants] = Field(default=None, description="Universal constants override")


# Example usage and factory functions
def create_sample_unicorn() -> MagicalUnicornInput:
    """Create a sample magical unicorn configuration"""
    return MagicalUnicornInput(
        name="Sparklehorn the Magnificent",
        horn_length=2.5,
        rainbow_intensity=85,
        magical_properties=MagicalProperties(
            spell_power=75,
            enchantment_type=EnchantmentType.LIGHTNING,
            runic_inscriptions=["THUNDER", "STORM", "POWER"],
            magical_reagents=MagicalReagents(
                dragon_scale=3,
                unicorn_hair=12,
                pixie_dust=5.5
            ),
            mana_capacity=8500.0,
            is_blessed=True
        ),
        preferred_habitat="cloud_castle"
    )


def create_sample_quantum_resource() -> SchrodingersResourceInput:
    """Create a sample quantum resource configuration"""
    return SchrodingersResourceInput(
        name="quantum-cat-experiment-001",
        initial_state="superposition",
        quantum_properties=QuantumProperties(
            wave_function="ψ(x,t) = α|alive⟩ + β|dead⟩",
            observer_effect=False,
            entangled_with=[],
            probability_cloud={"state_alive": 0.5, "state_dead": 0.5},
            uncertainty_principle=UncertaintyPrinciple(
                position_uncertainty=1e-10,
                momentum_uncertainty=1e-24
            ),
            coherence_time=1000.0
        ),
        half_life=42.0,
        isolation_level="maximum"
    )


def create_sample_time_paradox() -> TimeParadoxInput:
    """Create a sample time paradox configuration"""
    return TimeParadoxInput(
        name="The Bootstrap Enigma",
        paradox_type=ParadoxType.BOOTSTRAP,
        target_timestamp=datetime(2025, 1, 1, 12, 0, 0),
        severity_level=7
    )


if __name__ == "__main__":
    # Example validation and usage
    print("=== Nonsense Provider Schema Models ===\n")
    
    # Test unicorn creation
    unicorn = create_sample_unicorn()
    print(f"Sample Unicorn: {unicorn.name}")
    print(f"Horn Length: {unicorn.horn_length} magical units")
    print(f"Rainbow Intensity: {unicorn.rainbow_intensity}%")
    print(f"Spell Power: {unicorn.magical_properties.spell_power}")
    print()
    
    # Test quantum resource
    quantum = create_sample_quantum_resource()
    print(f"Quantum Resource: {quantum.name}")
    print(f"Wave Function: {quantum.quantum_properties.wave_function}")
    print(f"Half Life: {quantum.half_life} time units")
    print()
    
    # Test time paradox
    paradox = create_sample_time_paradox()
    print(f"Time Paradox: {paradox.name}")
    print(f"Type: {paradox.paradox_type}")
    print(f"Severity: {paradox.severity_level}/10")
    print()
    
    # Test function inputs
    nonsense_input = GenerateNonsenseInput(
        length=200,
        style="quantum-physics",
        include_emojis=True,
        complexity_level=0.8
    )
    print(f"Nonsense Generation Config: {nonsense_input.style} style, {nonsense_input.length} chars")
    
    print("\n=== All models validated successfully! ===")