import json
import os
from pathlib import Path

from groq import Groq


# ============================================================
# FCW - GROQ FAILURE ANALYSIS
#
# INPUT:
#   reports/failed_tests.json
#
# OUTPUT:
#   reports/failure_analysis.json
#
# ROLE:
#   - Lire les tests FCW FAILED
#   - Envoyer seulement les FAIL au LLM
#   - Produire un diagnostic probable
#   - Ne jamais modifier le verdict PASS / FAIL
# ============================================================


# ------------------------------------------------------------
# 1. CHEMINS DU PROJET
# ------------------------------------------------------------

PROJECT_DIR = Path(__file__).resolve().parent

REPORT_DIR = PROJECT_DIR / "reports"

FAILED_TESTS_FILE = REPORT_DIR / "failed_tests.json"

ANALYSIS_FILE = REPORT_DIR / "failure_analysis.json"


# ------------------------------------------------------------
# 2. MODELE GROQ
# ------------------------------------------------------------

MODEL_NAME = "openai/gpt-oss-120b"


# ============================================================
# FONCTION : LIRE LES TESTS FAILED
# ============================================================

def load_failed_tests():

    if not FAILED_TESTS_FILE.exists():
        raise FileNotFoundError(
            f"Failed tests file not found: {FAILED_TESTS_FILE}"
        )

    with open(
        FAILED_TESTS_FILE,
        "r",
        encoding="utf-8"
    ) as file:

        data = json.load(file)

    # MATLAB peut produire un objet seul
    # lorsqu'il n'existe qu'un seul FAIL
    if isinstance(data, dict):
        data = [data]

    if not isinstance(data, list):
        raise ValueError(
            "failed_tests.json must contain a JSON object or array."
        )

    return data


# ============================================================
# FONCTION : CREER LE CLIENT GROQ
# ============================================================

def create_groq_client():

    api_key = os.getenv("GROQ_API_KEY")

    if not api_key:
        raise RuntimeError(
            "GROQ_API_KEY is not configured."
        )

    return Groq(
        api_key=api_key
    )


# ============================================================
# FONCTION : CONSTRUIRE LE PROMPT
# ============================================================

def build_prompt(test):

    test_json = json.dumps(
        test,
        indent=2,
        ensure_ascii=False
    )

    prompt = f"""
You are an automotive ADAS Model-Based Design validation assistant.

You are analyzing a failed MIL test for a Forward Collision Warning
function executed with Simulink Test Manager.

============================================================
IMPORTANT VALIDATION RULES
============================================================

1. Simulink Test Manager is the authority for PASS/FAIL.

2. You MUST NEVER change the PASS/FAIL verdict.

3. A failed verification can have several possible origins:

   A. Model/software defect
   B. Incorrect expected value in the test case
   C. Incorrect test configuration
   D. Simulation or numerical issue

4. You MUST consider ALL of these possibilities.

5. Do NOT automatically assume that the Simulink model is defective
   simply because expected and actual outputs are different.

6. Expected values may themselves be incorrect.

7. Technical warnings are supporting evidence only.

8. A warning such as division by zero MUST NOT automatically be
   considered the root cause.

9. Separate clearly:

   - observed facts
   - mismatches
   - hypotheses
   - probable causes
   - recommended checks

10. If the available information is insufficient to identify the
    true root cause, explicitly say so.

11. Avoid unsupported certainty.

12. Base your analysis only on the supplied test data.

============================================================
FCW ENGINEERING CONTEXT
============================================================

Consider relevant FCW concepts such as:

- relative distance
- relative speed
- TTC
- SAFE / YELLOW / RED warning states
- warning thresholds
- target presence
- target lane validity
- state transitions
- boundary conditions
- numerical conditions
- test oracle / expected values

============================================================
FAILED TEST DATA
============================================================

{test_json}

============================================================
REQUIRED ANALYSIS
============================================================

Provide the analysis using the following structure:

1. DIRECT FAILURE SUMMARY

Explain exactly which expected values differ from actual values.

2. OBSERVED EVIDENCE

List only facts directly present in the supplied test data.

3. POSSIBLE ROOT-CAUSE CATEGORIES

Evaluate separately:

A. Incorrect expected values / test oracle
B. Model or FCW logic defect
C. Test configuration defect
D. Numerical / simulation issue

For each category, explain whether it is:

- plausible
- weakly supported
- strongly supported
- not supported

4. TECHNICAL WARNING ANALYSIS

Analyze any technical warning.

Explicitly state whether its relationship with the failed verification
is proven, plausible, or unproven.

5. RECOMMENDED ENGINEERING CHECKS

Give concrete checks an engineer should perform.

Examples:

- verify Excel expected outputs
- verify FCW requirement corresponding to this scenario
- inspect TTC calculation
- inspect SAFE/YELLOW/RED thresholds
- inspect state transition conditions
- inspect target-present and target-in-lane logic
- reproduce the test manually
- compare with neighboring PASS test cases

6. MOST LIKELY AREAS TO INSPECT

Rank the most relevant model/test areas to inspect.

7. DIAGNOSTIC CONCLUSION

Give a concise conclusion.

IMPORTANT:

If the available data cannot distinguish between a wrong expected
value and a real model defect, say explicitly:

"The available evidence is insufficient to determine whether the
expected test value or the model implementation is incorrect."

Do NOT invent missing requirements.
"""

    return prompt


# ============================================================
# FONCTION : ANALYSER UN TEST AVEC GROQ
# ============================================================

def analyze_test(client, test):

    test_id = test.get(
        "test_id",
        "UNKNOWN_TEST"
    )

    print()
    print("--------------------------------------------")
    print(f"Analyzing {test_id}")
    print("--------------------------------------------")

    prompt = build_prompt(test)

    completion = client.chat.completions.create(

        model=MODEL_NAME,

        messages=[
            {
                "role": "system",
                "content": (
                    "You are a technical automotive ADAS "
                    "MIL validation diagnostic assistant. "
                    "You distinguish test-data defects, "
                    "model defects, configuration defects "
                    "and simulation issues."
                ),
            },

            {
                "role": "user",
                "content": prompt,
            },
        ],

        temperature=0.1,

        max_completion_tokens=3000,
    )

    analysis_text = (
        completion
        .choices[0]
        .message
        .content
    )

    return {
        "test_id": test_id,
        "status": test.get("status"),
        "llm_model": MODEL_NAME,
        "analysis": analysis_text,
    }


# ============================================================
# FONCTION PRINCIPALE
# ============================================================

def main():

    print()
    print("============================================")
    print(" FCW GROQ FAILURE ANALYSIS")
    print("============================================")

    # --------------------------------------------------------
    # Creer reports/ si necessaire
    # --------------------------------------------------------

    REPORT_DIR.mkdir(
        parents=True,
        exist_ok=True
    )

    # --------------------------------------------------------
    # Lire les FAIL
    # --------------------------------------------------------

    failed_tests = load_failed_tests()

    print(
        f"Failed tests detected: {len(failed_tests)}"
    )

    # --------------------------------------------------------
    # Aucun FAIL
    # --------------------------------------------------------

    if len(failed_tests) == 0:

        print()
        print("No failed tests detected.")
        print("Groq API call skipped.")

        with open(
            ANALYSIS_FILE,
            "w",
            encoding="utf-8"
        ) as file:

            json.dump(
                [],
                file,
                indent=2,
                ensure_ascii=False
            )

        print()
        print("Analysis file generated:")
        print(ANALYSIS_FILE)

        return

    # --------------------------------------------------------
    # Creer client Groq
    # --------------------------------------------------------

    client = create_groq_client()

    analyses = []

    # --------------------------------------------------------
    # Analyser chaque FAIL
    # --------------------------------------------------------

    for test in failed_tests:

        try:

            result = analyze_test(
                client,
                test
            )

            analyses.append(
                result
            )

            print(
                f"{result['test_id']} -> analysis completed"
            )

        except Exception as error:

            test_id = test.get(
                "test_id",
                "UNKNOWN_TEST"
            )

            print(
                f"{test_id} -> Groq analysis failed"
            )

            print(
                f"Error: {error}"
            )

            analyses.append(
                {
                    "test_id": test_id,
                    "status": test.get("status"),
                    "llm_model": MODEL_NAME,
                    "analysis_status": "ERROR",
                    "error": str(error),
                }
            )

    # --------------------------------------------------------
    # Sauvegarder failure_analysis.json
    # --------------------------------------------------------

    with open(
        ANALYSIS_FILE,
        "w",
        encoding="utf-8"
    ) as file:

        json.dump(
            analyses,
            file,
            indent=2,
            ensure_ascii=False
        )

    # --------------------------------------------------------
    # Resume
    # --------------------------------------------------------

    print()
    print("============================================")
    print(" GROQ ANALYSIS FINISHED")
    print("============================================")

    print(
        f"Failed tests analyzed: {len(analyses)}"
    )

    print()
    print("Analysis generated:")
    print(ANALYSIS_FILE)


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    main()