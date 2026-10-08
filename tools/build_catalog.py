#!/usr/bin/env python3
"""Compile authored family concepts into stable runtime records. No AI at runtime.

The 200 records are a design draft, NOT evidence of 200 finished sprite sets.
Rebuild deterministically; do not change IDs after shipping saves.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Names | element | silhouette | ecology | characteristic move | combat role
THREE = '''
잎귀,살구귀,과수지기|nature|접힌 잎 귀와 살구 씨앗 주머니를 가진 연두색 겨울잠쥐|먹고 남은 씨앗을 돌담 아래 숨겨 오래된 과수원을 넓힌다|씨앗 튕기기|support
꿀종,밀랍종,황금종지기|nature|투명한 꿀 배와 꽃가루 목도리를 가진 종 모양 딱정벌레|비가 오기 전 배를 울려 꽃을 닫으라는 신호를 보낸다|꿀방울 소나기|ranged
갈대콩,물병수달,여울지기|water|갈대 목도리와 물병 등껍질을 가진 둥근 수달|메마른 웅덩이에 물을 나르고 치어가 떠내려가지 않게 돌을 놓는다|여울 밀치기|defender
등불솜,달무늬나방,밤길안내자|shade|버섯 무늬의 비대칭 보라 날개와 등불 더듬이가 있는 나방|길 잃은 새끼를 빛으로 인도하지만 큰 소리를 내면 불을 끈다|등불 가루|support
흙말이,기와등,돌담수호자|stone|붉은 기와 모양 비늘과 삽 꼬리를 가진 천산갑|무너진 둑을 몸으로 받치고 빈 비늘에 작은 풀을 키운다|기와 굴리기|defender
휘파람깃,바람꼬리,하늘돛새|wind|청록색 말린 볏과 주황 리본 꼬리의 작은 새|꼬리에 바람 방향을 기록해 철새들에게 안전한 길을 알려준다|휘파람 돌풍|swift
물방울발,수면춤꾼,연못무희|water|접시처럼 넓은 발끝과 수정 구슬 배를 지닌 소금쟁이|물 위에 둥근 파문을 그려 짝에게 연못 깊이를 전한다|파문 고리|swift
늪주머니,수초맹꽁,습지악사|water|턱 아래 갈대 공명통이 자라는 납작한 맹꽁이|물 높이에 따라 다른 음을 내어 마을의 홍수를 예고한다|갈대 합창|support
조개잠,진주꿈,기억조개|shade|잠든 얼굴을 닮은 흰 조개와 떠다니는 작은 진주|자신을 구해 준 생물의 목소리를 진주에 잠시 저장한다|메아리 진주|ranged
꼬마닻,녹닻게,항구파수꾼|metal|닻 모양 집게와 둥근 녹청 등판을 가진 게|버려진 쇠를 모아 어린 물고기가 숨는 집을 만든다|닻 끌어당기기|defender
소금털,해무양,구름목자|wind|해무 같은 둥근 털과 산호색 나선 뿔을 가진 양|몸에 모인 소금으로 해안 풀밭의 균형을 맞춘다|해무 장막|support
모래실,유리누에,사구직공|stone|투명한 등판 안으로 모래가 흐르는 누에|해변의 깨진 유리를 둥근 실로 감싸 발을 다치지 않게 한다|유리실 덫|ranged
조수꼬리,썰물여우,푸른밀물|water|파도처럼 두 갈래로 갈라진 꼬리와 흰 소금 눈썹의 여우|썰물에 드러나는 길을 외워 조개잠의 보금자리를 지킨다|조수 가르기|swift
석탄코,온돌두더지,산맥아궁이|flame|코가 작은 화로이고 등에는 평평한 석판이 있는 두더지|겨울이면 버려진 굴을 덥혀 다른 종이 함께 잠들게 한다|온돌 숨결|defender
찻돌,점토주전자,붉은다관|flame|주전자 주둥이와 짧은 바퀴 발을 가진 점토 생물|절벽의 약초를 우려 다친 여행자에게 따뜻한 물을 나눈다|끓는 물결|support
균열뿔,절벽영양,협곡도약자|stone|지층 무늬 뿔과 넓은 고무 같은 발굽을 가진 영양|벼랑을 두드려 낙석 위험을 알아내고 어린 종을 우회시킨다|지층 도약|swift
구리씨,새싹코일,숲발전기|metal|구리 고리에 새싹이 감겨 자라는 작은 발전 생물|낙엽이 썩는 열을 모아 톱니마을의 밤등을 밝힌다|새싹 전류|ranged
톱밥꼬리,공방비버,수차장인|metal|넓은 자 꼬리와 나무 톱니 앞니를 가진 비버|잘린 나무마다 묘목을 심는 조건으로 사람의 수차를 고친다|톱니 연타|balanced
재깍눈,태엽올빼미,시계탑현자|metal|한쪽 눈이 모래시계이고 날개가 얇은 황동 잎인 올빼미|기계 소음 속에서도 잠든 새끼의 심장 소리를 찾아낸다|시간차 깃털|ranged
이슬관,유리싹,온실심장|nature|유리 종 안에서 자라는 심장 모양 잎과 덩굴 발|공장 공기를 맑게 하지만 지나친 연기에는 유리가 흐려진다|정화 맥박|support
버섯신,균사걸음,숲우편부|nature|신발 같은 버섯 갓 두 개와 가는 균사 다리를 가진 종|나무 뿌리를 따라 영양과 냄새의 소식을 전달한다|균사 연결|support
그늘접시,달그릇,밤샘사슴|shade|초승달 접시 모양 뿔과 검푸른 벨벳 털의 사슴|뿔에 고인 달빛으로 밤에만 피는 꽃을 살핀다|달빛 저수|defender
메아리알,동굴울림,천음박쥐|shade|공명 구멍이 난 달걀 몸과 종이 같은 긴 날개의 박쥐|사라진 동굴의 길을 울음으로 기억해 길잡이에게 들려준다|반향 찌르기|ranged
이끼눈,낡은가면,숲의기억|shade|이끼 눈썹이 자란 나무 가면과 뿌리 망토|버려진 이름표를 모아 숲을 떠난 사람의 이야기를 기억한다|기억의 그림자|balanced
눈솜발,서리토끼,흰길달리미|frost|눈 결정 모양 발바닥과 파란 귀 끝을 가진 긴다리 토끼|새 눈 위에 단단한 발자국 길을 남겨 작은 종을 돕는다|서리 발자국|swift
온천알,수증기펭귄,안개목욕장|water|목욕 수건 같은 흰 깃과 김 나는 물주머니의 펭귄|얼어붙은 물가에 온천수를 조금씩 나르며 통로를 만든다|따뜻한 분출|support
얼음실,설사누에,빙하직조자|frost|실타래 몸에 반투명 고드름 실을 두른 누에|눈사태 뒤 갈라진 얼음을 얇고 질긴 실로 잇는다|빙사 묶기|ranged
바늘털,솔방울곰,겨울숲지기|nature|솔방울 등털과 도톰한 수지 발바닥을 가진 곰|동면할 때도 등의 솔방울을 열어 새들에게 씨앗을 준다|솔방울 포격|defender
별가루발,운석족제비,궤도여행자|star|발끝에 운석 가루가 붙고 긴 꼬리가 고리로 말리는 족제비|밤하늘에서 떨어진 돌을 원래 자리로 돌려보내려 모은다|궤도 질주|swift
나침반눈,자철부엉,북극성파수꾼|metal|나침반 같은 얼굴판과 자철석 깃털의 부엉이|폭풍에도 북쪽을 잊지 않아 바람꼬리의 항로를 바로잡는다|자북 섬광|ranged
구름발굽,산릉사슴,새벽수평선|wind|긴 구름 갈기와 등 위 수평선 무늬를 가진 사슴|아침마다 산 안개를 밀어 계곡 풀밭에 햇빛을 돌려준다|새벽 달리기|swift
혜성꼬리,유성가오리,밤하늘유영자|star|넓은 마름모 날개와 긴 불꽃 없는 혜성 꼬리의 가오리|별빛을 따라 공중을 헤엄치며 길 잃은 빛 벌레를 모은다|유성 활강|ranged
첫잎,숲숨결,천년의싹|nature|씨앗 껍질 머리와 사슴 같은 나무 몸통|서로 다른 숲의 씨앗을 품어 불탄 땅에 여러 종의 집을 만든다|첫숲의 호흡|support
샘방울,깊은샘,물기억고래|water|작은 우물 입과 물결 등지느러미가 있는 공중 고래|한 번 흘렀던 강의 방향을 몸 안의 물결로 간직한다|기억의 범람|defender
불씨발,화산잠꾸러기,용암돌침대|flame|불씨 발톱과 현무암 베개 등판을 가진 잠꾸러기 도마뱀|식은 용암 틈을 데워 새싹코일이 겨울을 나도록 돕는다|현무암 숨결|defender
문양실,비단지도,세상짜임|star|날개에 지형 등고선이 자라는 비단 나비|다른 종이 오간 길을 날개 무늬로 남겨 옛 숲의 지도를 완성한다|별자리 직조|support
도토리투구,참나무기사,고목성채|nature|도토리 투구와 고목 방패를 드는 작은 장수풍뎅이|오래된 나무의 빈 구멍을 차지하지 않고 새끼 종에게 내준다|고목 방벽|defender
먹구름씨,소낙도롱뇽,비구름용|water|등을 따라 작은 구름이 늘어선 남색 도롱뇽|메마른 계곡에서 잠들면 며칠 뒤 소나기가 내린다고 한다|소나기 행진|ranged
소리조약,울림바위,산의목소리|stone|입 대신 여러 크기의 구멍이 난 둥근 돌 생물|산속 모든 굴의 울림을 이어 먼 곳의 낙석을 먼저 알아챈다|산울림|defender
빛실눈,오로라족제비,극광길잡이|star|긴 몸을 감싼 얇은 극광 띠와 흰 눈썹|눈보라 속 온천의 위치를 빛실로 알려 길 잃은 종을 이끈다|극광 궤적|swift
'''
TWO = '''
물풀핀,수초바늘|water|물풀 같은 지느러미를 가진 바늘 물고기|갈대콩이 만든 둑 사이로 치어를 안내한다|물풀 찌르기|swift
진흙수염,늪바닥현자|stone|부채처럼 펼쳐지는 진흙 수염의 메기|늪 바닥의 오래된 물길을 수염으로 더듬는다|진흙 부채|defender
돛귀,산들돛귀|wind|작은 돛을 닮은 커다란 귀의 사막여우|바람이 없는 날에는 소금털의 털 그늘에서 쉰다|돛귀 밀풍|swift
등대눈,등대부리|star|눈 주위가 등대 렌즈처럼 빛나는 바다새|안개 낀 밤 항구파수꾼이 만든 집으로 물고기를 인도한다|등대 광선|ranged
산호발,산호왕관|water|산호 가지로 된 발과 둥근 말미잘 머리|바다에 버려진 유리를 모래실에게 가져다준다|산호 꽃피기|support
붉은먼지,협곡회오리|wind|작은 돌들이 몸 주변을 도는 붉은 먼지 생물|날카로운 돌을 둥글게 깎아 강가에 내려놓는다|먼지 회전|swift
석영눈,수정뿔소|stone|육각 석영 눈과 짧고 넓은 수정 뿔의 코뿔소|어두운 광산에서 몸에 저장한 햇빛을 나눠 준다|석영 돌진|defender
화덕빵,화덕멧돼지|flame|등의 구멍에서 구운 곡식 냄새가 나는 작은 멧돼지|주민이 말린 열매를 등에 얹으면 따뜻하게 데워 준다|화덕 박치기|balanced
증기톡,구름굴뚝|metal|굴뚝 머리와 짧은 증기 다리를 가진 작은 주철 생물|톱니마을의 폐열을 모아 온실심장에게 보낸다|증기 고리|ranged
자석발,자석집게|metal|발마다 둥근 자석이 달린 가느다란 집게벌레|공방 바닥의 쇳조각을 주워 새끼들의 발을 보호한다|자력 모으기|defender
수지콩,호박등|nature|나무 수지 안에 작은 씨앗을 품은 호박색 딱정벌레|상처 난 나무에 수지를 남겨 벌레가 들어오지 못하게 한다|수지 봉합|support
톱니씨앗,회전꽃|metal|꽃잎이 둥근 목제 톱니인 바닥에 붙은 꽃|공방비버와 함께 물 흐름만으로 돌아가는 장치를 만든다|회전 꽃잎|ranged
잠꼬리,꿈주머니|shade|꿈 주머니처럼 부풀어 오른 꼬리의 족제비|불안한 새끼의 곁에서 자면 꼬리가 천천히 작아진다|꿈 안개|support
잉크발,그림자서기|shade|발끝에서 보랏빛 먹이 나오는 긴다리 왜가리|말라 버린 연못에 옛 물길을 그림으로 남긴다|먹빛 획|ranged
거미별,밤그물|star|배에 작은 별 점이 있고 가느다란 은실을 잣는 거미|등불솜이 쉬어 갈 흔들리지 않는 그물을 친다|별그물|support
나무구멍,속빈수호자|nature|몸통에 새가 쉴 둥근 구멍이 있는 나무 올빼미|낡은가면이 모은 이름표를 비에 젖지 않게 보관한다|속빈 울림|defender
고드름수염,설벽바다표범|frost|길고 단단한 고드름 수염의 통통한 바다표범|두꺼운 얼음에 숨구멍을 내어 물방울발을 살린다|고드름 부채|ranged
눈꽃등,눈꽃순록|frost|등과 뿔에 여섯 갈래 눈꽃이 피는 작은 순록|발굽으로 눈을 걷어 겨울숲지기의 씨앗을 찾는다|눈꽃 퍼짐|support
서릿돌,빙벽거북|frost|지붕 같은 넓은 얼음 등판의 거북|눈사태를 등으로 받아 작은 종의 피난처가 된다|빙벽 세우기|defender
온기꼬리,겨울난로|flame|붉은 목도리 꼬리와 숯 귀의 작은 담비|온천펭귄의 물주머니가 식지 않도록 곁에서 잠든다|온기 물결|support
별조개,하늘진주|star|허공에 떠서 천천히 열리는 남색 조개|유성가오리가 흘린 별가루를 둥근 진주로 만든다|천구 진주|ranged
풍향코,산릉코끼리|wind|풍향계처럼 돌아가는 코와 얇은 귀의 작은 코끼리|폭풍이 올 때 나침반눈과 함께 안전한 계곡을 찾는다|풍향 전환|defender
달발,초승달삵|shade|발톱 끝이 초승달처럼 희고 귀가 긴 삵|밤샘사슴의 달빛을 따라 해로운 포자를 찾아낸다|초승달 베기|swift
종이깃,편지학|wind|접은 편지 모양 깃과 잉크색 부리의 학|숲우편부가 갈 수 없는 계곡 너머로 씨앗을 나른다|편지 날개|swift
우물잠,샘의수호수|water|몸 안에 잔잔한 우물이 보이는 작은 나무짐승|깊은샘이 잠든 곳에 뿌리를 내려 물을 맑게 한다|샘물 고동|support
불꽃종,새벽종지기|flame|불꽃 모양 손잡이가 있는 붉은 종 생물|사라진 마을의 아침 종소리를 아직도 기억한다|새벽 종소리|ranged
이정표꼬리,오래된길|stone|꼬리에 화살표 모양 돌이 달린 네발짐승|사람이 떠나도 오래된 샘과 숲 사이의 길을 지킨다|길잡이 돌진|balanced
거울잎,연못거울|nature|빛나는 둥근 잎과 가느다란 물뿌리의 생물|달그릇이 모은 빛을 물속 식물에 반사해 준다|반사 잎맥|support
별먼지,궤도핵|star|다섯 개의 작은 돌이 둥근 핵을 따라 도는 생물|운석족제비가 모아 놓은 돌 사이에서 태어난다|궤도 충돌|ranged
뿌리매듭,인연고목|nature|서로 다른 나무뿌리가 매듭지어진 느린 사슴|천년의싹이 퍼뜨린 여러 나무의 기억을 함께 품는다|인연의 뿌리|defender
'''
SINGLE = '''
찻잎귀|nature|찻잎 같은 넓은 귀와 흰 수염의 작고 긴 쥐|찻돌의 물이 너무 뜨거우면 귀로 바람을 보내 식힌다|찻잎 부채|support
꽃시계|nature|시간에 따라 다른 꽃잎을 펴는 둥근 거북|황금종지기의 울음에 맞추어 꽃을 열고 닫는다|꽃시계 맥박|support
물수제비|water|납작한 돌 몸에 물빛 날개를 가진 제비|어린 수초바늘에게 빠른 물살을 건너는 법을 보여준다|수면 도약|swift
낡은부표|water|밧줄 수염과 구멍 난 둥근 부표 몸의 생물|해무양이 길을 잃지 않도록 같은 바다에 머문다|부표 반동|defender
돛단해마|wind|등지느러미가 삼각 돛이고 꼬리가 닻인 해마|바다의 편지학이 떨어뜨린 씨앗을 해안에 가져다준다|돛단 돌풍|swift
도자기잠|stone|깨진 도자기 조각을 금빛 흙으로 이은 작은 게|붉은다관이 버린 조각을 모아 자기 집을 고친다|금흙 봉합|support
불먹는솔|flame|검은 솔방울 몸과 부드러운 빗자루 꼬리|산불 뒤 남은 불씨를 먹어 첫잎이 뿌리내릴 자리를 만든다|잔불 삼키기|defender
우표여우|wind|옆구리에 우표처럼 네모난 털무늬가 있는 여우|숲우편부의 냄새를 기억해 새 길을 알려준다|소식 질주|swift
폐철꽃|metal|낡은 작은 기어 안에서 다섯 꽃잎이 핀 생물|버려진 기계를 천천히 흙으로 되돌려 구리씨를 먹인다|녹꽃 흩날리기|support
손바닥등|metal|따뜻한 손 모양 갓 아래 호박빛이 나는 램프 생물|공방의 마지막 사람이 나갈 때까지 빛을 꺼뜨리지 않는다|손등 섬광|ranged
잠자는문|shade|작은 나무문 얼굴과 이끼 신발의 생물|나무구멍의 집을 대신 지키며 밤새 조용히 꿈을 꾼다|꿈 문턱|defender
도깨비실|shade|매듭진 붉은 실이 작은 탈 얼굴을 매단 생물|밤그물에 걸린 잎을 풀어 나방이 다치지 않게 한다|매듭 속박|swift
눈편지|frost|한 장의 접힌 눈 결정과 투명한 새 발|눈마루 주민이 봄에 읽을 이야기를 눈 속에 보관한다|눈결정 편지|ranged
얼지않는꽃|flame|투명한 얼음 줄기 끝의 작은 주황 꽃|빙벽거북의 등에서 자라 얼음이 갈라지는 속도를 늦춘다|따뜻한 꽃가루|support
구름열쇠|wind|열쇠처럼 생긴 꼬리와 구름 몸의 작은 날짐승|새벽수평선이 밀어 놓은 안개의 틈을 다시 이어준다|구름 문열기|swift
별읽는돌|star|하늘을 향한 한 개의 눈과 천체 궤도 무늬의 돌|북극성파수꾼이 쉬는 밤 대신 하늘의 변화를 기록한다|별자리 낙하|ranged
첫울음|star|고동치는 씨앗을 가슴에 품은 반투명 새|모든 지역의 첫 새벽 소리가 모인 분지에서만 태어난다|처음의 노래|support
마지막잎|nature|한 장의 금빛 잎을 뿔 끝에 매단 늙지 않는 사슴|인연고목이 잊을 뻔한 숲의 마지막 계절을 기억한다|계절 되감기|defender
비의우편함|water|작은 우편함 등껍질과 빗방울 발을 가진 달팽이|비구름용이 지나는 날에만 오래된 숲의 냄새를 전한다|빗방울 배달|support
순환의짐승|star|아홉 생태의 흔적이 서로 다른 뿔에 남은 큰 사슴|인연고목과 물기억고래의 기억을 이어 끊긴 서식지의 길을 되살린다|아홉 길의 맥박|balanced
'''

REGIONS = [
    ('새봄마을','풀빛 들판','목장지기 소율','trainer',18,'78ab65','e1c18a'),
    ('물버들마을','물안개 습지','갈대 둥지의 수호자','wild',20,'609b85','b9bc8a'),
    ('솔바람항','바람 해안','등대지기 하진','trainer',22,'91b786','e8d4a0'),
    ('적토마을','붉은 협곡','절벽의 기와등','wild',22,'b18563','d7a875'),
    ('톱니마을','이끼 공방','수차장인 로운','trainer',24,'799778','c5b294'),
    ('등불마을','달그늘 숲','잊힌 숲의 목소리','wild',24,'567d76','b3a393'),
    ('눈마루마을','서리 고원','온천지기 은서','trainer',24,'b9d2cc','d5d9c0'),
    ('별마루마을','별빛 산릉','별을 잇는 수호자','wild',26,'7787ac','c3c1cf'),
    ('첫숲의 분지','인연의 숲','순환의짐승','wild',20,'7dafa0','decca3')]
COLORS = {'nature':'8bbb69','water':'69adc2','wind':'b1d1b0','shade':'b4a1cc','stone':'c98d66','metal':'c6af7a','flame':'e09a64','frost':'afdbe1','star':'b0b5e5'}
ROLES = {'balanced':[66,60,58,56,56,55], 'swift':[48,65,42,52,43,82], 'ranged':[49,42,43,80,58,62], 'defender':[87,53,78,41,67,31], 'support':[67,38,51,64,71,49]}
SLOTS = {'D':1,'C':2,'B':3,'A':4,'S':4}

def main():
    families=[]
    for expected, source in [(3, THREE),(2,TWO),(1,SINGLE)]:
        for line in source.strip().splitlines():
            fields=line.split('|')
            names=fields[0].split(',')
            assert len(names)==expected, names
            families.append((names,*fields[1:]))
    assert len(families)==90, len(families)
    species=[]; skills={}; regions=[]
    for i,(town,field,boss,kind,count,grass,path) in enumerate(REGIONS):
        regions.append(dict(id=f'r{i}',index=i,town=town,name=field,boss_name=boss,boss_kind=kind,
            allocation=count,grass=grass,path=path,level_min=2+i*4,level_max=6+i*4,
            boss_level=6+i*4,description=f'{town}에서 시작해 {field}의 생태와 숨겨진 길을 발견하세요.'))
    for fi,(names,element,shape,ecology,signature,role) in enumerate(families):
        next_family=families[(fi+1)%len(families)][0][0]
        for stage,name in enumerate(names):
            idx=len(species); sid=f'm{idx+1:03}'
            region=next(i for i in range(9) if idx<sum(r['allocation'] for r in regions[:i+1]))
            rank=(['D','C','B'][stage] if len(names)==3 else ['C','A'][stage] if len(names)==2 else 'S' if fi>=82 else 'B')
            factor={'D':0.8,'C':1.,'B':1.2,'A':1.45,'S':1.7}[rank]
            pools=[]
            for slot in range(4):
                pool=[]
                for variant in range(2):
                    skill_id=f'f{fi+1:02}_s{stage}_{slot}_{variant}'
                    effect=['damage','heal','shield','slow'][slot]
                    if variant==1: effect=['slow','damage','damage','heal'][slot]
                    label=(signature if slot==0 else ['','생태의 숨결','서식지 방벽','길잡이 파동'][slot])
                    if variant: label='변주 · '+label
                    skills[skill_id]=dict(id=skill_id,name=label,element=element,effect=effect,
                        power=round((14+slot*5+variant*3)*factor),windup=round(.3+slot*.15,2),
                        cooldown=3.5+slot*1.5+variant,range=88+slot*12,color=COLORS[element])
                    pool.append(skill_id)
                pools.append(pool)
            attrs=['어린 개체는 주변의 소리와 냄새에 귀를 기울이며 안전한 길을 배운다.',
                   '성장하면서 자기 서식지의 변화를 먼저 알아차리고 어린 동료를 이끈다.',
                   '오랫동안 살아온 개체는 계절이 바뀌는 순서를 기억해 다른 종의 이동을 돕는다.']
            lore=f'{shape}. {ecology}. {attrs[min(stage,2)]} 가까운 서식지의 {next_family} 계열과 길을 공유하지만, 같은 자원을 쓰는 시기는 달라 서로의 보금자리를 해치지 않는다.'
            species.append(dict(id=sid,dex=idx+1,name=name,family=f'f{fi+1:02}',stage=stage,
                element=element,role=role,rank=rank,slots=SLOTS[rank],region=region,
                base_stats=[round(n*factor) for n in ROLES[role]],catch_rate=max(.2,.8-stage*.18),
                skill_pools=pools,evolves_to=f'm{idx+2:03}' if stage<len(names)-1 else '',
                evolution_level=12+stage*14 if stage<len(names)-1 else 0,
                sprite_row=-1,sprite_status='missing_final',
                concept=shape,ecology=ecology,lore=lore,lore_status='draft',related_name=next_family,
                color=COLORS[element]))
    assert len(species)==200
    names_to_ids={s['name']:s['id'] for s in species}
    for s in species:s['related_species']=names_to_ids[s.pop('related_name')]
    for r in regions:r['boss_species']=next(s['id'] for s in reversed(species) if s['region']==r['index'])
    data=dict(schema_version=1,regions=regions,species=species,skills=skills)
    (ROOT/'data/catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    lines=['# Content bible — design draft, not finished art','',
           '200 stable species IDs; 90 authored family concepts. All lore and cross-species links require editorial review.',
           'Visual work follows [DESIGN_AGENT.md](../DESIGN_AGENT.md). Rejected art was deleted; all sprites are missing.',
           'Founders atlas contains six base forms / six poses. Evolved forms and remaining families do NOT have approved animation.',
           'The runtime may display clearly marked study silhouettes for missing assets. They are not final designs.','',
           '|ID|종|티어|지역|역할|디자인·생태|진화|아트 상태|','|---|---|---|---|---|---|---|---|']
    for s in species:lines.append(f"|{s['id']}|{s['name']}|{s['rank']}|{regions[s['region']]['town']}|{s['role']}|{s['concept']}. {s['ecology']}.|{s['evolves_to'] or '—'}|{s['sprite_status']}|")
    (ROOT/'docs/CONTENT_BIBLE.md').write_text('\n'.join(lines)+'\n')
    print(f'Wrote {len(species)} species, {len(families)} families, {len(skills)} moves, {len(regions)} regions.')

if __name__=='__main__': main()
