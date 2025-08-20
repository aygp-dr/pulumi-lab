package main

import (
	"context"
	"fmt"
	"strings"
	"time"

	p "github.com/pulumi/pulumi-go-provider"
	"github.com/pulumi/pulumi-go-provider/infer"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// Pet breeds and types
type DogBreed string

const (
	GoldenRetriever DogBreed = "golden-retriever"
	LabradorRetriever DogBreed = "labrador-retriever"
	GermanShepherd   DogBreed = "german-shepherd"
	Bulldog         DogBreed = "bulldog"
	Poodle          DogBreed = "poodle"
	Beagle          DogBreed = "beagle"
	Rottweiler      DogBreed = "rottweiler"
	Husky           DogBreed = "husky"
)

type PetSize string

const (
	Small  PetSize = "small"
	Medium PetSize = "medium"
	Large  PetSize = "large"
	ExtraLarge PetSize = "extra-large"
)

type TrainingLevel string

const (
	Untrained   TrainingLevel = "untrained"
	Basic       TrainingLevel = "basic"
	Intermediate TrainingLevel = "intermediate"
	Advanced    TrainingLevel = "advanced"
	Professional TrainingLevel = "professional"
)

func main() {
	p.RunProvider("pets", "0.1.0", provider())
}

// Create the provider using infer
func provider() p.Provider {
	return infer.Provider(infer.Options{
		Resources: []infer.InferredResource{
			infer.Resource(&Dog{}),
			infer.Resource(&DogWalk{}),
			infer.Resource(&VeterinaryVisit{}),
			infer.Resource(&DogTraining{}),
			infer.Resource(&PetInsurance{}),
		},
		Functions: []infer.InferredFunction{
			infer.Function(&CalculateFeedingSchedule{}),
			infer.Function(&GenerateDogName{}),
			infer.Function(&PredictBehavior{}),
		},
	})
}

// Dog Resource
type Dog struct{}

type DogArgs struct {
	Name              string        `pulumi:"name"`
	Breed             DogBreed      `pulumi:"breed"`
	Age               *int          `pulumi:"age,optional"`
	Weight            *float64      `pulumi:"weight,optional"`
	Size              *PetSize      `pulumi:"size,optional"`
	IsGoodBoy         *bool         `pulumi:"isGoodBoy,optional"`
	FavoriteActivity  *string       `pulumi:"favoriteActivity,optional"`
	OwnerName         string        `pulumi:"ownerName"`
	Microchipped      *bool         `pulumi:"microchipped,optional"`
	VaccinationStatus *string       `pulumi:"vaccinationStatus,optional"`
	TrainingLevel     *TrainingLevel `pulumi:"trainingLevel,optional"`
}

type DogState struct {
	DogArgs
	ID                string    `pulumi:"id"`
	RegistrationDate  string    `pulumi:"registrationDate"`
	Health            string    `pulumi:"health"`
	Happiness         int       `pulumi:"happiness"`
	Energy            int       `pulumi:"energy"`
	LastFed           string    `pulumi:"lastFed"`
	LastWalk          string    `pulumi:"lastWalk"`
	TotalWalks        int       `pulumi:"totalWalks"`
	TotalTreats       int       `pulumi:"totalTreats"`
	BehaviorNotes     []string  `pulumi:"behaviorNotes"`
	MedicalHistory    []string  `pulumi:"medicalHistory"`
}

func (Dog) Create(ctx context.Context, name string, input DogArgs, preview bool) (string, DogState, error) {
	state := DogState{DogArgs: input}
	
	if preview {
		return name, state, nil
	}

	// Generate unique ID
	state.ID = fmt.Sprintf("dog-%s-%d", strings.ToLower(strings.ReplaceAll(input.Name, " ", "-")), time.Now().Unix())
	state.RegistrationDate = time.Now().Format("2006-01-02T15:04:05Z")
	
	// Set defaults based on breed and input
	if input.Age == nil {
		age := 2 // Default puppy age
		state.Age = &age
	}
	
	if input.IsGoodBoy == nil {
		goodBoy := true // All dogs are good boys/girls!
		state.IsGoodBoy = &goodBoy
	}
	
	if input.Size == nil {
		size := determineSizeByBreed(input.Breed)
		state.Size = &size
	}
	
	if input.Weight == nil {
		weight := estimateWeightByBreed(input.Breed)
		state.Weight = &weight
	}
	
	if input.TrainingLevel == nil {
		training := Basic
		state.TrainingLevel = &training
	}
	
	if input.VaccinationStatus == nil {
		status := "up-to-date"
		state.VaccinationStatus = &status
	}
	
	if input.Microchipped == nil {
		chipped := false
		state.Microchipped = &chipped
	}
	
	// Initialize dynamic state
	state.Health = "excellent"
	state.Happiness = 95
	state.Energy = 80
	state.LastFed = time.Now().Add(-4 * time.Hour).Format("2006-01-02T15:04:05Z")
	state.LastWalk = time.Now().Add(-2 * time.Hour).Format("2006-01-02T15:04:05Z")
	state.TotalWalks = 0
	state.TotalTreats = 0
	state.BehaviorNotes = []string{
		fmt.Sprintf("%s is a lovely %s who loves attention", input.Name, input.Breed),
		"Shows excellent potential for training",
	}
	state.MedicalHistory = []string{
		"Initial health check - all systems normal",
	}
	
	return state.ID, state, nil
}

func (Dog) Update(ctx context.Context, id string, oldState DogState, input DogArgs, preview bool) (DogState, error) {
	state := DogState{DogArgs: input}
	state.ID = oldState.ID
	state.RegistrationDate = oldState.RegistrationDate
	
	if preview {
		return state, nil
	}
	
	// Preserve dynamic state but allow updates
	state.Health = oldState.Health
	state.Happiness = oldState.Happiness
	state.Energy = oldState.Energy
	state.LastFed = oldState.LastFed
	state.LastWalk = oldState.LastWalk
	state.TotalWalks = oldState.TotalWalks
	state.TotalTreats = oldState.TotalTreats
	state.BehaviorNotes = oldState.BehaviorNotes
	state.MedicalHistory = oldState.MedicalHistory
	
	// Add update note
	state.BehaviorNotes = append(state.BehaviorNotes, 
		fmt.Sprintf("Updated information on %s", time.Now().Format("2006-01-02")))
	
	return state, nil
}

func (Dog) Delete(ctx context.Context, id string, state DogState) error {
	// Sad to see a dog go, but sometimes they find new homes
	return nil
}

// DogWalk Resource - represents taking a dog for a walk
type DogWalk struct{}

type DogWalkArgs struct {
	DogID       string  `pulumi:"dogId"`
	Duration    int     `pulumi:"duration"` // minutes
	Distance    float64 `pulumi:"distance"` // miles
	Route       *string `pulumi:"route,optional"`
	Weather     *string `pulumi:"weather,optional"`
	Notes       *string `pulumi:"notes,optional"`
	TreatsGiven *int    `pulumi:"treatsGiven,optional"`
}

type DogWalkState struct {
	DogWalkArgs
	ID        string `pulumi:"id"`
	Date      string `pulumi:"date"`
	Calories  int    `pulumi:"calories"`
	Enjoyment string `pulumi:"enjoyment"`
}

func (DogWalk) Create(ctx context.Context, name string, input DogWalkArgs, preview bool) (string, DogWalkState, error) {
	state := DogWalkState{DogWalkArgs: input}
	
	if preview {
		return name, state, nil
	}
	
	state.ID = fmt.Sprintf("walk-%s-%d", input.DogID, time.Now().Unix())
	state.Date = time.Now().Format("2006-01-02T15:04:05Z")
	
	// Calculate calories burned (rough estimate)
	state.Calories = int(input.Distance * 50 * float64(input.Duration) / 30)
	
	// Determine enjoyment based on duration and weather
	if input.Duration > 30 {
		state.Enjoyment = "high"
	} else if input.Duration > 15 {
		state.Enjoyment = "medium"
	} else {
		state.Enjoyment = "low"
	}
	
	if input.Weather != nil && (*input.Weather == "sunny" || *input.Weather == "mild") {
		state.Enjoyment = "high"
	}
	
	return state.ID, state, nil
}

// VeterinaryVisit Resource
type VeterinaryVisit struct{}

type VeterinaryVisitArgs struct {
	DogID       string   `pulumi:"dogId"`
	VisitType   string   `pulumi:"visitType"` // checkup, vaccination, emergency, surgery
	Symptoms    *string  `pulumi:"symptoms,optional"`
	Treatment   *string  `pulumi:"treatment,optional"`
	Cost        *float64 `pulumi:"cost,optional"`
	VetName     string   `pulumi:"vetName"`
	ClinicName  string   `pulumi:"clinicName"`
	FollowUp    *bool    `pulumi:"followUp,optional"`
}

type VeterinaryVisitState struct {
	VeterinaryVisitArgs
	ID          string   `pulumi:"id"`
	Date        string   `pulumi:"date"`
	Diagnosis   string   `pulumi:"diagnosis"`
	Medications []string `pulumi:"medications"`
	NextVisit   string   `pulumi:"nextVisit"`
}

func (VeterinaryVisit) Create(ctx context.Context, name string, input VeterinaryVisitArgs, preview bool) (string, VeterinaryVisitState, error) {
	state := VeterinaryVisitState{VeterinaryVisitArgs: input}
	
	if preview {
		return name, state, nil
	}
	
	state.ID = fmt.Sprintf("vet-%s-%d", input.DogID, time.Now().Unix())
	state.Date = time.Now().Format("2006-01-02T15:04:05Z")
	
	// Generate diagnosis based on visit type
	switch input.VisitType {
	case "checkup":
		state.Diagnosis = "Healthy and happy! No concerns noted."
		state.NextVisit = time.Now().AddDate(1, 0, 0).Format("2006-01-02")
	case "vaccination":
		state.Diagnosis = "Vaccination administered successfully."
		state.Medications = []string{"Annual vaccination booster"}
		state.NextVisit = time.Now().AddDate(1, 0, 0).Format("2006-01-02")
	case "emergency":
		state.Diagnosis = "Emergency condition treated and stabilized."
		state.NextVisit = time.Now().AddDate(0, 0, 7).Format("2006-01-02")
	case "surgery":
		state.Diagnosis = "Surgical procedure completed successfully."
		state.Medications = []string{"Pain medication", "Antibiotics"}
		state.NextVisit = time.Now().AddDate(0, 0, 14).Format("2006-01-02")
	default:
		state.Diagnosis = "General veterinary consultation completed."
		state.NextVisit = time.Now().AddDate(0, 6, 0).Format("2006-01-02")
	}
	
	return state.ID, state, nil
}

// Helper functions
func determineSizeByBreed(breed DogBreed) PetSize {
	switch breed {
	case Beagle, Poodle:
		return Medium
	case GoldenRetriever, LabradorRetriever, GermanShepherd, Rottweiler, Husky:
		return Large
	case Bulldog:
		return Medium
	default:
		return Medium
	}
}

func estimateWeightByBreed(breed DogBreed) float64 {
	switch breed {
	case Beagle:
		return 25.0
	case Poodle:
		return 45.0
	case GoldenRetriever:
		return 65.0
	case LabradorRetriever:
		return 70.0
	case GermanShepherd:
		return 75.0
	case Bulldog:
		return 50.0
	case Rottweiler:
		return 95.0
	case Husky:
		return 55.0
	default:
		return 50.0
	}
}

// Additional resources would continue in this pattern...
// DogTraining, PetInsurance, etc.

type DogTraining struct{}
type PetInsurance struct{}

// Function implementations
type CalculateFeedingSchedule struct{}
type GenerateDogName struct{}
type PredictBehavior struct{}

// These would have their own implementations following the same pattern...